#=========================================================
# XMPP Bridge - Main Module
#
# Copyright 2009 by Steve Gibson
# steve@stevegibson.com (xmpp and email)
#
# This is free software.  You can redistribute it and/or
# modify it under the terms of the BSD license.  See
# LICENSE for more details.
#
#=========================================================
  
class XMPPBridgeMain
    
  attr_accessor :xmpp, :std_msg_thread, :con_chk_thread, :status_msg, :accept_subs

  def initialize(database, botpasswd, accept_subs, debug_mode)
    
    #==================================================================
    # Setup Jabber client objects and threads
    #==================================================================
    
    Jabber::debug = debug_mode
    
    #cl = Jabber::Client.new(Jabber::JID.new($botjid))
    #cl.connect
    #cl.auth(botpasswd)
    
    # Create Jabber bot instance
    @status_msg = "#{$product} v#{$version} : Type !help for menu"
    @xmpp = Jabber::Simple.new($botjid,botpasswd,nil,@status_msg)
    @xmpp.accept_subscriptions=(accept_subs)
    @accept_subs = accept_subs
 
    # Create Iq::Version responder
    @iq_vr = Jabber::Version::SimpleResponder.new(@xmpp.client, $product, $version, $uname)
    
    # Setup the Ruby Sandbox where users can run ruby commands
    #$sbox = Sandbox.new
    
    # Get the start time
    $start_time = Time.now
    logit("connected")
    
    # Check for unsubscribed users and load reserved nicks
    # into $user_nicks array
    resultset = $db.query("SELECT rjid,rnick FROM roster")
    unless resultset == nil
      resultset.each {|row|
        ret_jid = row[0].to_s
        unless ret_jid # make sure the jid returned wasn't nil
          logit("Error: nil jid found in roster db while loading $user_nicks")
          next
        end
        ret_nick = row[1].to_s
        unless ret_nick # make sure the nick returned wasn't nil
          logit("Error: nil nick found in roster db while loading $user_nicks")
          logit("(using the default nick)")
          ret_nick = /^(.+)\@/.match(ret_jid)[1]
        end
        unsubscribed_users = Array.new
        unsubbed = nil
        @xmpp.roster.items.each do |j,r|
          if r.to_s.include?("subscription='none'")
            #remove jid from roster
            logit("Found #{j} with subscription 'none' -- removing from roster.")
            @xmpp.remove(j)
            #remove user from db
            logit("Removing #{j} from the user roster in the database.")
            $db.execute("DELETE FROM roster WHERE rjid='#{j}'")
            #remove from $user_nicks
            $user_nicks.delete(j)
            unsubbed = true
          end
        end
        unless unsubbed
          $user_nicks[ret_jid] = ret_nick
          logit("loaded reserved nick: #{ret_nick} (#{ret_jid})")
        end
      } 
    end
    resultset.close
    
    #==============================================================
    # Spawn a thread to receive standard xmpp messages
    #==============================================================
    @std_msg_thread = Thread.new do
      logit("spawned std_msg_thread")
      loop do
        sleep 0.1
    
        #==============================================================
        # Messages
        #
        @xmpp.received_messages do | message |
          received_messages_handler(message, debug_mode)
        end
    
        # new subscription updates
        #@xmpp.new_subscriptions do |contact, presence|
        #  begin
        #    if $banned_users.include?(contact.to_s)
        #      logit("Received subscription request from banned user: #{contact.to_s}")
        #      reply_user(contact.to_s, "You are banned.", $mtype)
        #      @xmpp.remove(contact.to_s)
        #    else
        #      logit("Received subscription update from #{contact.to_s}: #{presence.to_s}") 
        #    end
        #  rescue Exception => exp
        #    logit("Error (new_subscriptions): " + exp.to_s)
        #  end
        #end
    
        #=================================================================
        # New Presence Updates
        #
        @xmpp.presence_updates do |contact, presence|
          presence_updates_handler(contact,presence)
        end
      end
    end
    @std_msg_thread[:name] = "msg"
    $tg_msg.add(@std_msg_thread)
    
    #==============================================================
    # Timeout checker thread
    #==============================================================
    @timeout_check_thread = Thread.new do
      loop do
        sleep 60 
        begin
          $bridged_users.each_key do |user|
            lastseen = $db.get_first_value("SELECT lastseen FROM roster WHERE rjid='" + sql_sanitize(user) + "' AND lastpres='unavailable'")
            if check_timeout(lastseen, $bridged_app_timeout)
              logit("timeout for user: #{user} lastseen: #{lastseen}")
              quit_bridged_app(user)
            end
          end
        rescue Exception => e
          logit("Error (timeout_check_thread): " + e.to_s)
        end
      end
    end
    @timeout_check_thread[:name] = "toutchk"
    $tg_con.add(@timeout_check_thread)

    #==============================================================
    # Connection checker thread
    #==============================================================
    @con_check_thread = Thread.new do
      loop do
        sleep 10 
        if @xmpp.client.is_disconnected?
          # reconnect attempt 
          begin
            logit("Bot disconnected -- attempting to reconnect")
            @xmpp.reconnect
            logit("Reconnection successful.")
          rescue Exception
            logit("Error (con_check_thread): " + $!)
          end
        else
          #logit("bot is connected")
        end
      end
    end
    @con_check_thread[:name] = "conchk"
    $tg_con.add(@con_check_thread)
    
  end # initialize
  
  #==================================================================
  # Methods
  #==================================================================
  
  #==================================================================
  # Received Messages Handler
  #==================================================================
  def received_messages_handler(message, debug_mode)
    begin
      msgfrom = message.from.to_s
      ujid,rsrc = msgfrom.split(/\//)
    
      $total_msg_received += 1
      msgtimestring = GetTime()
      logit("Received message from #{ujid}: #{message.body}")
     
      # Check if from Banned JID
      if $banned_users.include?(ujid)
        reply_user(ujid, "You are banned. Reason: #{$banned_users[ujid]}", $mtype)
        @xmpp.remove(ujid)
      else
    
        # Check for messages from users using bridged apps and see if the 
        # app should "handle" them.
        if $bridged_users.include?(ujid) and not message.body =~ /^!/
          $mtype = "std"
          bridged_app = $bridged_users[ujid]
          bridged_app.process_msg(ujid, msgtimestring, message.body)
          logit("debug_mode:#{bridged_app.to_s} sending: #{message.body.chomp}") if debug_mode

        # Handle non-in-bridged-app messages
        else
          #logit("calling process_std_msg")
          process_std_msg(ujid, msgtimestring, message.body)
        end
    
      end # if banned
    
    rescue Exception => msg_err
      logit("Error processing message: " + msg_err.to_s)
    end 

  end

  #==================================================================
  # Presence Updates Handler
  #==================================================================
  def presence_updates_handler(contact,presence)
    begin
      ujid = contact.to_s
      if $banned_users.include?(ujid)
        logit("Received presence update from banned JID: #{ujid}: #{presence.to_s}")
        logit("Removing #{ujid} from contact list.")
        @xmpp.remove(ujid)
      else
        logit("Received presence update from #{ujid}: #{presence.to_s}")
        # Update Presence in db
        unless verify_user_db_entry(ujid)
          reply_user(ujid, "Setting your nickname to '#{$user_nicks[ujid]}'.  Use the !reserve command to select a new nickname.", "std")
        else 
          $db.execute("UPDATE roster SET lastpres='#{presence.to_s}' WHERE rjid='" + sql_sanitize(ujid) + "'")
          if presence.to_s == "online" and add_user_to_lobby?(ujid)
            unless $lobby_users.include?(ujid) or $bridged_users.include?(ujid) 
              $lobby_users.each do |u|
                reply_user(u, "#{$user_nicks[ujid]} has re-entered the lobby.", "std")
              end
              add_user_to_lobby(ujid)
              reply_user(ujid, "You've re-entered the lobby.", "std")
              logit("Adding #{ujid} to lobby: pres=#{presence.to_s} in_lobby=1.")
            end
          end
        end
    
        # Remove from chat lobby and set last seen time if we receive
        # presence "unavailable"
        if presence.to_s == "unavailable"
          seen = Time.now.strftime('%Y-%m-%d %H:%M:%S')
          $db.execute("UPDATE roster SET lastseen='#{seen}' WHERE rjid='" + sql_sanitize(ujid) + "'")
          #quit_bridged_app(ujid)
          leave_lobby(ujid, "unavailable")  
        end

      end
    rescue Exception => exp
      logit("Error (presence_updates): " + exp.to_s)
      logit("Error (presence_updates): " + exp.backtrace.join("\n"))
    end
  end

  #==================================================================
  # Standard Jabber Message Processor
  #==================================================================
  def process_std_msg(ujid, timestr, msg)
    begin
      # set message reply type to standard Jabber message
      $mtype = "std"
  
      # add user to $user_nicks if not already there
      unless $user_nicks.include?(ujid)
        nick = $db.get_first_value("SELECT rnick FROM roster WHERE rjid='" + sql_sanitize(ujid) + "'")
        #nick = /^(.+)\@/.match(ujid)[1]
        $user_nicks[ujid] = nick 
      end
  
      # if sending player is in the lobby, forward message to lobby occupants
      # and save message in $lobby_msg_history.
      if $lobby_users.include?(ujid)
        $lobby_users.each do |jid|
          unless jid == ujid
            reply_user(jid, "<#{$user_nicks[ujid]}> " + msg, $mtype)
          end
        end
        # catalogue message for the short term in a hash
        if $lobby_msg_history.length < 100
          $lobby_msg_history.insert(0, "[#{timestr} #{$user_nicks[ujid]}] #{msg.strip}") 
        else
          $lobby_msg_history.pop
          $lobby_msg_history.insert(0, "[#{timestr} #{$user_nicks[ujid]}] #{msg.strip}") 
        end 
      end
    
      # add cmd to cmdhist table if it is a ! command
      if (msg.strip =~ /^!.*$/) and not (msg.strip =~ /!cmdhist/)
        begin
          cmdtxt = msg.strip
          ts = Time.now
          logcmd(ts.strftime('%Y-%m-%d %H:%M:%S'), ujid, sql_sanitize(cmdtxt))
        rescue SQLite3::Exception
          logit("SQLite3 Error: " + $!)
        end
      end
  
      # check against array of Botcmd objects
      if msg.strip =~ /^!(.+?)$/
        cmdstring = $1
        name, arg1, arg2, arg3 = cmdstring.split(' ', 4)
        #reply_user(ujid, "parse results -- name: #{name}, arg1: #{arg1}, arg2: #{arg2}, arg3: #{arg3}", $mtype)
        match = nil
        $cmdarray.each do |cmdobj|
          #reply_user(ujid, "checking #{cmdobj.name} for match", $mtype)
          if (name == cmdobj.name) and ((cmdobj.type == :public) or isbotmaster?(ujid))
            #reply_user(ujid, "matched: #{cmdobj.name}", $mtype)
            if $show_code and isbotmaster?(ujid)
              reply_user(ujid, "code=#{cmdobj.code}", $mtype)
            end
  
            if cmdobj.return != nil
              str = eval(cmdobj.code).to_s
              reply_user(ujid, str, $mtype)
            else
              # The cmdobj.code will handle response to the user
              # itself.
              eval cmdobj.code
            end
            
            # found command so break out of do loop
            match = 1
            break
          end
        end
  
      # catch invalid commands
      elsif msg.strip =~ /^!/
        reply_user(ujid, "Invalid command. Type !help for help.", $mtype)
      end
    rescue Exception => e
      logit("Error (process_std_msg): " + e.to_s)
      reply_user(ujid, "Error (process_std_msg): " + e.to_s + "\n" + e.backtrace.join, $mtype)
    end
  end

  #==================================================================
  # Check timeout of bridged apps for 'unavailable' users
  #==================================================================
  def check_timeout(lastseen, minutes)
    return false unless lastseen 
    ls_time = DateTime.parse(lastseen)
    if DateTime.now.min - ls_time.min > minutes
      return true
    else
      return false
    end
  end 

  #==================================================================
  # Check if user should be added to lobby when presence detected
  #==================================================================
  def add_user_to_lobby?(ujid)
    # Check for their in_lobby setting to see if they have a db entry
    in_lobby = $db.get_first_value("SELECT in_lobby FROM roster WHERE rjid='" + sql_sanitize(ujid) + "'")
    if in_lobby == "1"
      return true
    else
      return false
    end
  end 
  
  #==================================================================
  # Verify user db entry
  #==================================================================
  def verify_user_db_entry(ujid)
    # Check for their in_lobby setting to see if they have a db entry
    in_lobby = $db.get_first_value("SELECT in_lobby FROM roster WHERE rjid='" + sql_sanitize(ujid) + "'")
    unless in_lobby == "0" or in_lobby == "1" # This means they have no roster entry - create one
      logit("Adding new roster entry for #{ujid}.")
      # Check to see if their default nick is already taken
      taken = nil
      default_nick = /^(.+)\@/.match(ujid)[1]
      if default_nick
        logit("Default nick for #{ujid} = #{default_nick}.")
      else
        logit("Default nick for #{ujid} is nil!")
      end
      $user_nicks.each do |j, existing_nick|
        if existing_nick # make sure existing_nick isn't nil for some reason
          if default_nick.downcase == existing_nick.downcase and ujid != j
            taken = true
          end
        end
      end
      if taken
        default_nick = default_nick + rand(9999).to_s
        logit("Setting nick for #{ujid} to #{default_nick}.")
      end
      $db.execute("INSERT INTO roster (rjid,rlvl,rnick,rpasswd,lastseen,lastpres,in_lobby) VALUES ('" + sql_sanitize(ujid) + "','user','" + sql_sanitize(default_nick) + "','none','none','unknown','0')")
      $user_nicks[ujid] = default_nick
      return false
    else
      return true
    end
  end

  #==================================================================
  # Check if a user (jid) is a bot master
  #==================================================================
  def isbotmaster?(jid)
    if jid
      if jid == $botnick
        return true
      elsif $masters.include?(jid)
        return true
      else
        return false
      end
    end
    false
  end
    
  #==================================================================
  # Shortened reply_user function for use in evals while chatting with bot
  #==================================================================
  def ru(msg)
    reply_user(ujid, msg, $mtype)
  end
  
  #==================================================================
  # Get bot status message
  #==================================================================
  def get_status
    if $lobby_users.length == 0 and $bridged_users.length == 0
      "#{$product} v#{$version} : Type !help for menu"
    else
      "L=#{$lobby_users.length.to_s} B=#{$bridged_users.length.to_s} : #{$product} v#{$version} : Type !help for menu"
    end
  end
  
  #==================================================================
  # Leave Lobby
  #==================================================================
  def leave_lobby(ujid, reason)
    begin
      reason = "exit" if reason == nil
      if $lobby_users.include?(ujid)
        $lobby_users.delete(ujid)
        $lobby_users.each do |u|
          reply_user(u, "#{$user_nicks[ujid]} has left the lobby (reason: #{reason}).", "std")
        end
        reply_user(ujid, "You have left the lobby (reason: #{reason}).", "std")
        #@xmpp.status(nil, get_status)
        seen = Time.now.strftime('%Y-%m-%d %H:%M:%S')
        $db.execute("UPDATE roster SET lastseen='#{seen}' WHERE rjid='" + sql_sanitize(ujid) + "'")
      end
    rescue Exception => e
      logit("Error (leave_lobby): " + e.to_s)
    end
  end

  #==================================================================
  # Add user to Lobby
  #==================================================================
  def add_user_to_lobby(ujid)
    begin
      if $lobby_users.include?(ujid)
        return
      else
        $lobby_users << ujid
        seen = Time.now.strftime('%Y-%m-%d %H:%M:%S')
        $db.execute("UPDATE roster SET lastseen='#{seen}' WHERE rjid='" + sql_sanitize(ujid) + "'")
      end
    rescue Exception => e
      logit("Error (add_user_to_lobby): " + e.to_s)
    end

  end
    
  #==================================================================
  # Quit bridged app
  #==================================================================
  def quit_bridged_app(ujid)
    begin
      if $bridged_users.include?(ujid)
        bridge_app = $bridged_users[ujid]
        bridge_app.disconnect(ujid)
      end
    rescue Exception => e
      logit("Error (quit_bridged_app): " + e.to_s)
      $bridged_users.delete(ujid)
    end
  end
  
  #==================================================================
  # Notify bot masters
  #==================================================================
  def notify(msg)
    $masters.each do |jid|
      reply_user(jid, msg, "std")
    end
  end
  
  #==================================================================
  # Get time stamp
  #==================================================================
  def GetTime
    msgtime = Time.now
    msgtime.strftime('%H:%M:%S')
  end
   
  #==================================================================
  # Log command
  #==================================================================
  def logcmd(timestamp, jid, cmd)
    $db.execute("INSERT INTO cmdhist(time, jid, cmd) VALUES ('#{timestamp}', '#{jid}', '#{cmd}')")
  end
  
end # Class
