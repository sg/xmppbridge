#=====================================================
# MUCBot XMPPBridge module
#
# This module creates a "bot" connection or "bridge"
# to the specified MUC room.
#
#  Copyright 2009 by Steve Gibson
#  steve@stevegibson.com (xmpp and email)
#
#  This is free software.  You can redistribute it and/or
#  modify it under the terms of the BSD license.  See
#  LICENSE for more details.
#
#====================================================


# Set any global vars prior to MUCbot Class code
$master_initiated_leave = false

#==================================================================
# MUC Bot Class
#==================================================================
class MUCBot

  attr_accessor :version, :room_jid, :password, :botnick, :auto_rejoin, :allow_public_commands, :room_alias, :monitors, :master_nicks, :muc_number, :mucbot, :joined_room, :chatroom_roster 

  def initialize(elements)

    @version = "1.0"

    @mucbot = nil
    @occupant_count = 0
    @starttime = Time.now
    @joined_room = false

    @elements = elements
    @room_jid = @elements[:room_jid]
    @password = @elements[:password]
    @botnick = @elements[:botnick]
    @room_alias = @elements[:room_alias]
    @auto_rejoin = @elements[:auto_rejoin]
    @allow_public_commands = @elements[:allow_public_commands]

    @chatroom_roster = Hash.new
    @monitors = Array.new
    @master_nicks = Array.new
    @muc_number = 0
     
    # get highest muc_number from MUCBots in ObjectSpace
    begin
      highest = 0
      ObjectSpace.each_object(MUCBot) do |m|
        if m.muc_number > highest
          highest = m.muc_number
        end
      end
    rescue Exception => e
      reply_user(ujid, "Error MUCBot.initialize: " + e.to_s, $mtype)
    end
    @muc_number = highest + 1

    # kick off a new thread to handle everything
    @muc_thread = Thread.new do
      begin
        logit("new @mucbot [#{@muc_number}] for: #{@room_jid} alias: #{@room_alias}")
        @mucbot = Jabber::MUC::SimpleMUCClient.new($b.xmpp.client)

        #callbacks

        @mucbot.on_message do |time,nick,text|
          self.handle_pub_msg(time,nick,text)
        end

        @mucbot.on_private_message do |time,nick,text|
          self.handle_priv_msg(time,nick,text)
        end

        @mucbot.on_room_message do |time,text|
          self.handle_room_msg(time,text)
        end

        @mucbot.on_subject do |time,nick,jid,subject|
          self.handle_change_topic(time,nick,jid,subject)
        end

        @mucbot.on_join do |time,nick|
          self.handle_join(time,nick)
        end

        @mucbot.on_leave do |time,nick|
          self.handle_leave(time,nick)
        end

        @mucbot.on_self_leave do
          self.handle_self_leave()
        end

        self.join_room()

      rescue Exception => e
        logit("Error (@muc_thread): " + e.to_s)
      end
    end # @muc_thread
    @muc_thread[:name] = "muc:#{@muc_number}"
  end # initialize


  def join_room
    #join_thread
    join_thread = Thread.new do
      begin
        $b.notify("Attempting to join: #{@room_jid}/#{@botnick} alias: [#{@muc_number}]#{@room_alias}")
        @mucbot.join("#{@room_jid}/#{@botnick}", @password)
      rescue Exception => ex
        logit("Error joining #{@room_jid}: " + ex.to_s)
        $b.notify("Error joining #{@room_jid}: " + ex.to_s)
      end
    end
    join_thread[:name] = "mucjoin:#{@muc_number}"
    unless join_thread.join(10)
      $b.notify("Error: timeout on joining room #{@room_jid}")
      logit("Error: timeout on joining room #{@room_jid}")
      Thread.kill(join_thread)
    else
      $b.notify("Joined room [#{@muc_number}]#{@room_alias} #{@room_jid}.")
      logit("Joined room [#{@muc_number}]#{@room_alias} #{@room_jid}.")
      @joined_room = true
      Thread.kill(join_thread)
    end
    # if joining room failed, end the @muc_thread
    unless @joined_room
      @joined_room = false
      Thread.kill(@muc_thread)
      #unless @muc_thread.join(3)
      #  $b.notify("Error: timed out waiting for muc_thread to exit")
      #  logit("Error: timed out waiting for muc_thread to exit")
      #end
    end
  end

  def handle_join(time,nick)
    begin
      ujid = nil
      if @mucbot.roster.has_key?(nick)
        fullpresence = @mucbot.roster[nick]        
        #logit("fullpresence = " + fullpresence.to_s)
        fullpresence.to_s.match(/jid='(.+?)\//)
        ujid = $1
      else
        logit("DEBUG: didn't find '#{nick}' in @mucbot.roster!")
      end
      if ujid == nil
        ujid = "nil-jid"
      end
      unless $botjid.downcase == ujid.downcase
        @chatroom_roster[nick] = ujid
        logit("[#{@muc_number}]#{@room_alias}: #{nick}(#{ujid}) has joined.")
        @monitors.each do |monitor_jid|
          reply_user(monitor_jid, "[#{@muc_number}]#{@room_alias}: #{nick}(#{ujid}) has joined.", "std")
        end
      end
    rescue Exception => e
      logit("Error (mucbot.handle_join): " + e.to_s)
    end    
  end # handle_join

  def handle_leave(time,nick)
    logit("[#{@muc_number}]#{@room_alias}: #{nick} has left.")
    @monitors.each do |monitor_jid|
      reply_user(monitor_jid, "[#{@muc_number}]#{@room_alias}: #{nick} has left.", "std")
    end
    if @chatroom_roster.has_key?(nick)
      @chatroom_roster.delete(nick)
    end
    if @master_nicks.include?(nick)
      @master_nicks.delete(nick)
      $b.notify("[#{@muc_number}]#{@room_alias}: removing recognized nick (#{nick}).")
    end
  end # handle_leave

  def handle_priv_msg(time,nick,text)
    begin
      ujid = nick
      # *NOTE: the 'ujid' variable here is actually the user's nick
      #  we're just calling it ujid since that's what the Botcmd objects
      #  expect.
      $total_msg_received += 1
      notadmin = "You must be a bot admin to use this command."
      $mtype = "priv:" + @muc_number.to_s
      # forward to all people on the monitor list
      @monitors.each do |monitor_jid|
        reply_user(monitor_jid, "[#{@muc_number}]#{@room_alias}: [PRIV]<#{nick}> #{text}", "std")
      end
    rescue Exception => e
      logit("Error (handle_priv_msg): " + e.to_s)
    end
  end # handle_priv_msg

  def handle_pub_msg(time,nick,text)
    begin
      ujid = nick
      # *NOTE: the 'ujid' variable here is actually the user's nick
      #  we're just calling it ujid since that's what the Botcmd objects
      #  expect.
      $total_msg_received += 1
      notadmin = "#{nick}, you must be a bot admin to use that command."
      $mtype = "pub:" + @muc_number.to_s

      # Avoid reacting on messages delivered as room history
      unless time
        timestamp = $b.GetTime()
        # forward to all people on the monitor list
        @monitors.each do |monitor_jid|
          reply_user(monitor_jid, "[#{@muc_number}]#{@room_alias}: <#{nick}> #{text}", "std")
        end
      end #unless time
    rescue Exception => e
      logit("Error (handle_pub_msg): " + e.to_s)
    end
  end # handle_pub_msg

  def handle_room_msg(time,text)
    begin
      logit("[#{@muc_number}]#{@room_alias}[ROOM]: #{text}")
      # forward to all people on the monitor list
      @monitors.each do |monitor_jid|
        reply_user(monitor_jid, "[#{@muc_number}]#{room_alias}[ROOM]: #{text}", "std")
      end
    rescue Exception => e
      logit("Error (handle_room_msg): " + e.to_s)
    end
  end

  def handle_change_topic(time,nick,jid,subject)
    logit("#{nick} set room topic to: #{subject}")
  end

  def handle_self_leave
    begin
      unless $master_initiated_leave
        logit("disconnected from room [#{@muc_number}]#{room_alias} #{@room_jid}")
        # forward to all bot masters
        $b.notify("disconnected from room [#{@muc_number}]#{room_alias} #{@room_jid}")

        # attempt to rejoin room
        begin
          logit("attempting to auto-rejoin room [#{@muc_number}]#{room_alias} #{@room_jid}")
          join_room()
          $b.notify("Auto-Rejoined room [#{@muc_number}]#{room_alias} #{@room_jid}")
        rescue Exception => e
          logit("Error (auto-rejoin [#{@muc_number}]#{room_alias} #{@room_jid}): " + e.to_s)
          $b.notify("Error (auto-rejoin [#{@muc_number}]#{room_alias} #{@room_jid}): " + e.to_s)
        end
      end
      $master_initiated_leave = false
    rescue Exception => ex
      logit("Error (handle_self_leave): " + ex.to_s)
    end
  end # handle_self_leave

  def process_msg(ujid, msgtimestr, msgbody)
    # Not doing any internal processing to this message
    # since this isn't a true app that a user "enters".
    # The mucbot app uses a seperate command (!s) for
    # sending messages to the room.
    # This method is only here as a placeholder.
  end
    
  def disconnect
    begin
      $master_initiated_leave = true
      @mucbot.exit
      Thread.kill(@muc_thread)
      logit("disconnected from room [#{@muc_number}]#{room_alias} #{@room_jid}")
      $b.notify("disconnected from room [#{@muc_number}]#{room_alias} #{@room_jid} (by command)")
    rescue Exception => e
      logit("Error (@mucbot.disconnect): " + e.to_s)
    end
  end

end
