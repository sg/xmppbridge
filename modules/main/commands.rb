#=======================================================
#  Bot commands - to be loaded via "load 'main-commands.rb'"
#  in the main bot script.  The main script must
#  "require 'botcmd'" before loading this file.
#
#  Copyright 2009 by Steve Gibson
#  steve@stevegibson.com (xmpp and email)
# 
#  This is free software.  You can redistribute it and/or
#  modify it under the terms of the BSD license.  See
#  LICENSE for more details.
#=======================================================

# :type => :private means admin access only.
# :type => :public means anyone can run the command.

# !sample
$cmdarray.push(Botcmd.new(
  :name => 'sample',
  :type => :private,
  :code => %q{
    
    begin
      #code
      reply_user(ujid, "sample command template", $mtype)
    rescue Exception => e
      logit("Error (!sample): " + e.to_s)
      reply_user(ujid, "Error (!sample): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'sample command template'
  ))

# !acceptsubs
$cmdarray.push(Botcmd.new(
  :name => 'acceptsubs',
  :type => :private,
  :code => %q{
    
    begin
      #code
      if $b.accept_subs
        reply_user(ujid, "Setting accept_subs to false.", $mtype)
        $b.xmpp.accept_subscriptions=(false)
        $b.accept_subs = false
      else  
        reply_user(ujid, "Setting accept_subs to true.", $mtype)
        $b.xmpp.accept_subscriptions=(true)
        $b.accept_subs = true
      end
    rescue Exception => e
      logit("Error (!acceptsubs): " + e.to_s)
      reply_user(ujid, "Error (!acceptsubs): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'Toggle bot to accept or not accept subscriptions.'
  ))

# !listmodules
$cmdarray.push(Botcmd.new(
  :name => 'listmodules',
  :type => :private,
  :code => %q{
    
    begin
      #code
      $modules.each do |m|
        reply_user(ujid, "--> #{m}", $mtype)
      end
    rescue Exception => e
      logit("Error (!listmodules): " + e.to_s)
      reply_user(ujid, "Error (!listmodules): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'list loaded modules'
  ))

# BE CAREFUL with this command!!!
# !e <ruby expr>
$cmdarray.push(Botcmd.new(
  :name => 'e',
  :type => :private,
  :code => %q{
    
    begin
      eval_code = "#{arg1} #{arg2} #{arg3}"
      if eval_code =~ /[\s|\`|\(|\"]rm /
        logit "#{ujid}: !e #{eval_code}"
        logit "potentially unsafe: rm"
        reply_user(ujid, "potentially unsafe code -- can't run it", $mtype)
        return nil
      end
      logit "#{ujid} (eval): !e #{eval_code}"
      #str = $sbox.eval(eval_code)
      str = eval(eval_code).to_s
      logit "---- result ----"
      logit str
      logit "---- end ----"
      reply_user(ujid, str, $mtype)
    rescue Exception
      logit("Error (!e): " + $!)
      reply_user(ujid, "Error (!e): " + $!, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'eval() arbitrary ruby code. *** CAUTION!!! ***'
  ))

# !pid
$cmdarray.push(Botcmd.new(
  :name => 'pid',
  :type => :private,
  :code => %q{
    
    begin
      reply_user(ujid, Process.pid, $mtype)
    rescue Exception
      logit("Error (!pid): " + $!)
      reply_user(ujid, "Error (!pid): " + $!, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'display PID of the bot'
  ))

# !reload
$cmdarray.push(Botcmd.new(
  :name => 'reload',
  :type => :private,
  :code => %q{
    
    begin
      if arg1 == nil
        reply_user(ujid, "usage: !reload <module|cmd|all>", $mtype)
      elsif arg1 == "cmd"
        logit("#{ujid} issued a !reload cmd")
        $cmdarray = Array.new
        $modules.each do |m|
          load "modules/#{m}/commands.rb"
        end          
        reply_user(ujid, "Loaded #{$cmdarray.length.to_s} commands.", $mtype)
        logit("Loaded #{$cmdarray.length.to_s} commands.")
        reply_user(ujid, "--done--", $mtype)
      else
        matched = false
        $modules.each do |m|
          if arg1 == m or arg1 == "all"
            matched = true
            logit("#{ujid} issued a !reload #{m}")
            load "modules/#{m}/#{m}.rb"
            reply_user(ujid, "re-loaded the #{m} module", $mtype)
          end
        end          
        unless matched
          logit("#{ujid} issued a !reload #{arg1} -- but no such module was found")
          reply_user(ujid, "couldn't find a module named \"#{arg1}\"", $mtype)
        end
      end 
    rescue Exception
      logit("Error (!reload): " + $!)
      reply_user(ujid, "Error (!reload): " + $!, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'Reload bot modules'
  ))

# !die
$cmdarray.push(Botcmd.new(
  :name => 'die',
  :type => :private,
  :code => %q{
    
    begin
      logit("exiting") 
      $master_initiated_leave = true
      #unless $db.closed?
      #  $db.close
      #end
      $masters.each do |master_jid|
        reply_user(master_jid,"!die issued by #{ujid}.", "std")
      end
      $mainthread.wakeup
    rescue Exception => e
      logit("Error (!die): " + e.to_s)
      reply_user(ujid, "Error (!die): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'Cause the bot to disconnect and quit.'
  ))   

# !showcode
$cmdarray.push(Botcmd.new(
  :name => 'showcode',
  :type => :private,
  :code => %q{
  
  begin
    if $show_code
      $show_code = false
      reply_user(ujid, "*showcode OFF.", $mtype)
    else
      $show_code = true
      reply_user(ujid, "*showcode ON.", $mtype)
    end
  rescue Exception => e
    reply_user(ujid, "Error (!showcode): " + e.to_s)
  end
  },
  :return => nil,
  :helptxt => 'Toggle soure code output for exec\'d commands.'
  ))

# !debug <on|off>
$cmdarray.push(Botcmd.new(
  :name => 'debug',
  :type => :private,
  :code => %q{
  
  begin
    if arg1 == nil
      reply_user(ujid, "debug mode: " + Jabber::debug.to_s, $mtype)
    elsif arg1 == "on"
      Jabber::debug = true
      reply_user(ujid, "debug mode: " + Jabber::debug.to_s, $mtype)
    elsif arg1 == "off"
      Jabber::debug = false
      reply_user(ujid, "debug mode: " + Jabber::debug.to_s, $mtype)
    else 
      reply_user(ujid, "usage: !debug <on|off>", $mtype)
    end 
  rescue Exception => e
    reply_user(ujid, "Error (!debug): " + e.to_s)
  end
  },
  :return => nil,
  :helptxt => 'Toggle debug output to console.'
  ))

# !cmdhist
$cmdarray.push(Botcmd.new(
  :name => 'cmdhist',
  :type => :private,
  :code => %q{
    
    limit = arg1
    begin
      if limit
        resultset = $db.query("SELECT * FROM cmdhist ORDER BY time ASC LIMIT #{limit}")
      else
        resultset = $db.query("SELECT * FROM cmdhist ORDER BY time ASC LIMIT 10")
      end
      resultset.each {|row|
        timestamp = row[0]
        cmdjid = row[1]
        cmdstr = row[2]
        reply_user(ujid, "[#{timestamp}] #{cmdjid}: #{cmdstr}", $mtype)
      }
      resultset.close
    rescue SQLite3::Exception
      logit("SQLite3 Error (!cmdhist): " + $!)
      reply_user(ujid, "SQLite3: " + $!, $mtype)
    rescue Exception
      logit("Error (!cmdhist): " + $!)
      reply_user(ujid, "Error: " + $!, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'List bot command history.'
  ))

# !uptime
$cmdarray.push(Botcmd.new(
  :name => 'uptime',
  :type => :public,
  :code => %q{
  
  begin
    curtime = Time.now
    uptime = curtime.to_i - $start_time.to_i
    minutes, seconds = uptime.divmod(60)
    hrs, minutes = minutes.divmod(60)
    days, hours = hrs.divmod(24)
    reply_user(ujid, "Uptime:  #{days.to_s}d #{hours.to_s}h #{minutes.to_s}m #{seconds.to_s}s", $mtype)
  rescue Exception => e
    reply_user(ujid, "Error (!uptime): " + e.to_s)
  end
  },
  :return => nil,
  :helptxt => 'Time since bridge was last restarted.'
  ))

# !status
$cmdarray.push(Botcmd.new(
  :name => 'status',
  :type => :public,
  :code => %q{
  
  begin
    curtime = Time.now
    uptime = curtime.to_i - $start_time.to_i
    minutes, seconds = uptime.divmod(60)
    hrs, minutes = minutes.divmod(60)
    days, hours = hrs.divmod(24)
    reply_user(ujid, "#{$product} v#{$version} -- Status Report:",  $mtype)
    sleep 0.05
    reply_user(ujid, "==========================", $mtype)
    sleep 0.05
    reply_user(ujid, "Uptime:  #{days.to_s}d #{hours.to_s}h #{minutes.to_s}m #{seconds.to_s}s", $mtype)
    sleep 0.05
    reply_user(ujid, "Total received: #{$total_msg_received.to_s}", $mtype)
    reply_user(ujid, "Total sent: #{$total_msg_sent.to_s}", $mtype)
    sleep 0.05
    reply_user(ujid, "Roster count: " + $b.xmpp.roster.items.length.to_s, $mtype)
    sleep 0.05
    reply_user(ujid, "Active bridges: " + $bridges.length.to_s, $mtype)
    sleep 0.05
    if $bridges.length > 0
      bridge_type_hash = Hash.new
      $bridges.each do |g|
        if bridge_type_hash.include?(g.type)
          bridge_type_hash[g.type] += 1
        else
          bridge_type_hash[g.type] = 1
        end
      end
      bridge_str = ""
      bridge_type_hash.each do |k,v|
        bridge_str << "#{k}:#{v} "   
      end
      reply_user(ujid, "Bridge types: " + bridge_str, $mtype)
      sleep 0.05
    end
    retstr = `ps -eo pid,pcpu,size,vsize | grep #{Process.pid} | grep -v grep`
    retstr.chomp!
    reply_user(ujid, "Process status: #{retstr}", $mtype)
    reply_user(ujid, "Ruby #{RUBY_VERSION}", $mtype)
  rescue Exception => e
    reply_user(ujid, "Error (!status): " + e.to_s)
  end
  },
  :return => nil,
  :helptxt => "#{$product} status report."
  ))

# !boot
$cmdarray.push(Botcmd.new(
  :name => 'boot',
  :type => :private,
  :code => %q{
    
    begin
      if arg1 == nil
        reply_user(ujid, "usage: !boot <nick>", $mtype)
      else
        $user_nicks.each do |jid, existing_nick|
          if arg1 == existing_nick and $lobby_users.include?(jid)
            $lobby_users.delete(jid)
            logit("#{ujid} used !boot on #{existing_nick}(#{jid})")
          end
        end
      end
    rescue Exception => e
      reply_user(ujid, "Error (!boot): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'remove user from lobby.'
  ))

# !ban <jid|nick> [reason]
$cmdarray.push(Botcmd.new(
  :name => 'ban',
  :type => :private,
  :code => %q{
    
    jid = nil
    begin
      if arg1 == nil
        reply_user(ujid, "usage: !ban <jid|nick> [reason]", $mtype)
      else
        # determine jid or nick
        if arg1.include?('@') # looks like a jid
          jid = arg1
          if $user_nicks.include?(jid)
            nick = $user_nicks[jid]
          else
            nick = jid
          end
        else
          nick = arg1
          if $user_nicks.has_value?(nick)
            $user_nicks.each do |j,n|
              if nick == n
                jid = j
              end
            end
          else
            reply_user(ujid, "Could not find JID associated with '#{nick}'.", $mtype)
            jid = nil
          end
        end
        if arg2 == nil
          reason = "no reason specified"
        else
          reason = "#{arg2} #{arg3}"
        end

        # if jid isn't nil, then set the ban
        if jid
          if $banned_users.include?(jid)
            reply_user(ujid, "That JID is already banned.", $mtype)
            reply_user(ujid, "Entry: #{jid}: #{$banned_users[jid]}", $mtype)
          else
            $banned_users[jid] = reason
            $db.execute("INSERT INTO bans (jid,reason) VALUES ('" + sql_sanitize(jid) + "','" + sql_sanitize(reason) + "')")
            quit_bridged_app(jid)
            $b.leave_lobby(jid, "banned")
            reply_user(jid, "You have been banned (#{reason}).", $mtype)
            reply_user(ujid, "Removing #{jid} as a contact.", $mtype)
            $b.xmpp.remove(jid)
            $lobby_users.each do |u|
              reply_user(u, "#{nick} has been banned: #{reason}", $mtype)
            end
          end
        else
          reply_user(ujid, "Can't enact a ban on a nil JID.", $mtype)
        end # if jid

      end # if arg1 not nil
    rescue SQLite3::Exception => se
      reply_user(ujid, "SQLite3 Error (!ban): " + se.to_s, $mtype)
    rescue Exception => e
      reply_user(ujid, "Error (!ban): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'Ban a user jid from the bridge.'
  ))

# !unban <jid>
$cmdarray.push(Botcmd.new(
  :name => 'unban',
  :type => :private,
  :code => %q{
    
    begin
      if arg1 == nil
        reply_user(ujid, "usage: !unban <jid>", $mtype)
      else
        jid = arg1
        if $banned_users.include?(jid)
          $banned_users.delete(jid)
          $db.execute("DELETE FROM bans WHERE jid = '" + jid + "'")
          reply_user(ujid,"Removed ban on: #{jid}", $mtype)
          reply_user(jid,"The ban on your JID has been removed.", $mtype)
        else
          reply_user(ujid,"#{jid} is not on the ban list.", $mtype)
        end
      end
    rescue SQLite3::Exception => se
      reply_user(ujid, "SQLite3 Error (!unban): " + se.to_s, $mtype)
    rescue Exception => e
      reply_user(ujid, "Error (!unban): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'Unban a user jid.'
  ))

# !listbans
$cmdarray.push(Botcmd.new(
  :name => 'listbans',
  :type => :private,
  :code => %q{
    
    begin
      $banned_users.each do |jid,reason|
        reply_user(ujid, "JID: #{jid} Reason: #{reason}", $mtype)
      end
    rescue Exception => e
      reply_user(ujid, "Error (!listbans): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'List banned user jids.'
  ))

# !bridges
$cmdarray.push(Botcmd.new(
  :name => 'bridges',
  :type => :private,
  :code => %q{
    
    begin
      if $bridged_users.length > 0
        $bridged_users.each do |p, g|
            reply_user(ujid, "#{$user_nicks[p]}  [connected to #{g.type}]", $mtype)
        end
      else
        reply_user(ujid, "currently no active bridged applications", $mtype)
      end
    rescue Exception => e
      reply_user(ujid, "Error (!bridges): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'List active bridges.'
  ))

# !users
$cmdarray.push(Botcmd.new(
  :name => 'users',
  :type => :public,
  :code => %q{
    
    begin
      if $bridged_users.length > 0
        reply_user(ujid, "---- Bridged Users ----", $mtype)
        sleep 0.1
        $bridged_users.each do |p,g|
          if isbotmaster?(p)
            nick = '@' + $user_nicks[p] 
          else
            nick = $user_nicks[p]
          end
          if isbotmaster?(ujid)
            nick = nick + " (#{p})"
          end
          reply_user(ujid, "  #{nick} [connected to #{g.type}]", $mtype)
        end
      else
        reply_user(ujid, "No users bridged.", $mtype)
      end
      sleep 0.2
      if $lobby_users.length > 0
        reply_user(ujid, "---- Lobby ----", $mtype)
        sleep 0.1
        $lobby_users.each do |u|
          u_status = $db.get_first_value("SELECT lastpres FROM roster WHERE rjid = '" + sql_sanitize(u) + "'")
          u_status = "unknown status" if u_status == nil
          if isbotmaster?(u)
            nick = '@' + $user_nicks[u]
          else
            nick = $user_nicks[u]
          end
          if isbotmaster?(ujid)
            nick = nick + " (#{u})"
          end
          reply_user(ujid, "  #{nick} (#{u_status})", $mtype)
        end
      else
        reply_user(ujid, "No users in the lobby.", $mtype)
      end
    rescue Exception => e
      reply_user(ujid, "Error (!users): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'List connected users.'
  ))

# !roster [pattern]
$cmdarray.push(Botcmd.new(
  :name => 'roster',
  :type => :private,
  :code => %q{
    begin
      pattern = arg1
      resultset = nil
      if pattern
        resultset = $db.query("SELECT rjid,rnick,lastpres FROM roster WHERE rjid LIKE '%" + pattern + "%' OR rnick LIKE '%" + pattern + "%' OR lastpres LIKE '%" + pattern + "%'")
      else
        resultset = $db.query("SELECT rjid,rnick,lastpres FROM roster")
      end
      resultset.each do |row|
        reply_user(ujid, ">" + row.join(', '),$mtype)
      end
      resultset.close
    rescue SQLite3::Exception => se
      reply_user(ujid, "SQLite3 Error (!roster): " + se.to_s, $mtype)
    rescue Exception => e
      reply_user(ujid, "Error (!roster): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => "Print {$product} user roster from the database."
  ))
 
# !seen <nick>
$cmdarray.push(Botcmd.new(
  :name => 'seen',
  :type => :public,
  :code => %q{
    begin
      if arg1 == nil
        reply_user(ujid, "usage: !seen <nick>", $mtype)
      else
        nick = arg1
        jid = nil
        $user_nicks.each do |j,n|
          if nick.downcase == n.downcase
            jid = j
          end
        end
        in_lobby = nil
        $lobby_users.each do | ujid |
          if ujid == jid
            in_lobby = true
          end
        end
        if in_lobby
          reply_user(ujid, "#{nick} is currently in the lobby!", $mtype)
        else
          seen = $db.get_first_value("SELECT lastseen FROM roster WHERE rnick LIKE '" + nick + "'")
          if seen
            reply_user(ujid, "#{nick} was last seen #{seen}.", $mtype)
          else
            reply_user(ujid, "I have never seen #{nick} in the lobby.", $mtype)
          end
        end
      end
    rescue SQLite3::Exception => se
      reply_user(ujid, "SQLite3 Error (!seen): " + se.to_s, $mtype)
    rescue Exception => e
      reply_user(ujid, "Error (!seen): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'Report when user was last seen in the lobby.'
  ))


# !reserve <nick>
$cmdarray.push(Botcmd.new(
  :name => 'reserve',
  :type => :public,
  :code => %q{
    begin
      if arg1 == nil
        reply_user(ujid, "usage: !reserve <nickname>", $mtype)
      else
        nick = arg1
        taken = false
        $user_nicks.each do |jid, existing_nick|
          if nick.downcase == existing_nick.downcase and ujid != jid
            reply_user(ujid, "That nickname is already in use.", $mtype)
            taken = true
          end
        end
        unless taken
          found_jid = $db.get_first_value("SELECT rjid FROM roster WHERE rjid='" + ujid + "'")
          unless found_jid
            $db.execute("INSERT INTO roster (rjid,rlvl,rnick,rpasswd) VALUES ('" + sql_sanitize(ujid) + "','user','" + sql_sanitize(nick) + "','none')")
          else # this ujid has a nick entry, so update it to this one
            $db.execute("UPDATE roster SET rnick='" + sql_sanitize(nick) + "' WHERE rjid='" + sql_sanitize(ujid) + "'")
          end
          reply_user(ujid, "You've reserved the nickname: #{nick}", $mtype)
          $user_nicks[ujid] = nick
        end
      end
    rescue SQLite3::Exception => se
      reply_user(ujid, "SQLite3 Error (!reserve): " + se.to_s, $mtype)
    rescue Exception => e
      reply_user(ujid, "Error (!reserve): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'Reserve a nickname.'
  ))

# !telnet
$cmdarray.push(Botcmd.new(
  :name => 'telnet',
  :type => :private,
  :code => %q{
    begin
      player = ujid
      if arg1 == nil or arg2 == nil
        reply_user(ujid, "usage: !telnet <host> <port>", $mtype)
      else   
        if $bridged_users.include?(player)
          reply_user(player, "You are already bridged.  Use !quit first if you want to join or create a new bridge to another application or game.", $mtype)
        else
          $b.leave_lobby(player, "connecting to telnet session")
          reply_user(player, "Connecting to #{arg1}...", $mtype)
          logit("#{player} connecting to #{arg1}...")
          mush = MUSHclient.new(player, arg1, arg2)
          logit("#{player} connection successful.")
          $lobby_users.each do |u|
            reply_user(u, "#{$user_nicks[player]} connected to the MUSH.", $mtype)
          end
          $bridges << mush
          $bridged_users[player] = mush # add to player=>bridged_app hash
        end
      end
    rescue Exception => e
      reply_user(ujid, "Error (!telnet): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'use mushclient to \'telnet\' to a host and port.'
  ))

# !threads
$cmdarray.push(Botcmd.new(
  :name => 'threads',
  :type => :private,
  :code => %q{
  begin
    reply_user(ujid, "ThreadGroup: $tg_main", $mtype)
    $tg_main.list.each do |t|
      reply_user(ujid, "#{t[:name]} :: #{t.inspect}", $mtype)
    end
    reply_user(ujid, "----", $mtype)
    reply_user(ujid, "ThreadGroup: $tg_msg", $mtype)
    $tg_msg.list.each do |t|
      reply_user(ujid, "#{t[:name]} :: #{t.inspect}", $mtype)
    end
    reply_user(ujid, "----", $mtype)
    reply_user(ujid, "ThreadGroup: $tg_con", $mtype)
    $tg_con.list.each do |t|
      reply_user(ujid, "#{t[:name]} :: #{t.inspect}", $mtype)
    end
    reply_user(ujid, "----", $mtype)
    reply_user(ujid, "All Threads", $mtype)
    Thread.list.each do |t|
      reply_user(ujid, "#{t[:name]} :: #{t.inspect}", $mtype)
    end
    
  rescue Exception => e
    reply_user(ujid, "Error (!threads): " + e.to_s)
  end
  },
  :return => nil,
  :helptxt => "List threads."
  ))

# !ping [host]
$cmdarray.push(Botcmd.new(
  :name => 'ping',
  :type => :private,
  :code => %q{
  begin
    if arg1 == nil
      reply_user(ujid, "pong!", $mtype)
    else
      #reply = Net::Ping
      reply_user(ujid, "Pinging a host is currently disabled.", $mtype)
    end
  rescue Exception => e
    reply_user(ujid, "Error (!ping): " + e.to_s)
  end
  },
  :return => nil,
  :helptxt => "Ping a host or get a 'pong!' reply from the bot."
  ))

# !sql <query>
$cmdarray.push(Botcmd.new(
  :name => 'sql',
  :type => :private,
  :code => %q{
    querystr = "#{arg1} #{arg2} #{arg3}"
    begin
      resultset = $db.query(querystr)
      resultset.each do |row|
        reply_user(ujid, ">" + row.join(', '),$mtype)
      end
      resultset.close
    rescue SQLite3::Exception #SQLite3::SQLException
      logit("Error (!sql): " + $!)
      reply_user(ujid, "SQLite3: " + $!,$mtype)
    rescue Exception #SQLite3::SQLException
      logit("Error (!sql): " + $!)
      reply_user(ujid, "Error: " + $!,$mtype)
    end
  },
  :return => nil,
  :helptxt => 'Executes SQL statement on current database.'
  ))

# !dblist
$cmdarray.push(Botcmd.new(
  :name => 'dblist',
  :type => :private,
  :code => %q{
  begin
    Dir.foreach(".") do |filename|
      if filename.include?(".db")
        reply_user(ujid, filename, $mtype)
      end
    end
  rescue Exception => e
    reply_user(ujid, "Error (!dblist): " + e.to_s)
  end
  },
  :return => nil,
  :helptxt => 'Lists datbases available.'
  ))

# !dbopen <database file>
$cmdarray.push(Botcmd.new(
  :name => 'dbopen',
  :type => :private,
  :code => %q{
  begin
    database = arg1
    if File.exists?(database)
      if $db.closed?
        $db = SQLite3::Database.new(database)
        reply_user(ujid, "opened #{database}.", $mtype)
        reply_user(ujid, @db.table_info.to_s, $mtype)
      else
        $db.close
        $db = SQLite3::Database.new(database)
        reply_user(ujid, "opened #{database}.", $mtype)
        #reply_user(ujid, @db.table_info.to_s, $mtype)
      end
    else
      reply_user(ujid, "database #{database} does not exit.", $mtype)
    end
  rescue Exception => e
    reply_user(ujid, "Error (!dbopen): " + e.to_s)
  end
  },
  :return => nil,
  :helptxt => 'Open the specified database file.'
  ))

# !quit
$cmdarray.push(Botcmd.new(
  :name => 'quit',
  :type => :public,
  :code => %q{
  player = ujid
  begin
    if $bridged_users.include?(player)
      bridged_app = $bridged_users[player]
      bridged_app.disconnect(player)
      $lobby_users.each do |user|
        reply_user(user, "#{$user_nicks[player]} has entered the lobby.", $mtype)
      end
      #$b.xmpp.status(nil, $b.get_status)
    else
      reply_user(player, "You aren't currently bridged to an external app or game.", $mtype)
    end
  rescue Exception => e
    logit("Error (!quit): " + e.to_s)
    reply_user(ujid, "Error (!quit): " + e.to_s, $mtype)
    $bridged_users.delete(player)
    reply_user(player, "Entering lobby...", $mtype)
    $b.add_user_to_lobby(player)
  end
  },
  :return => nil,
  :helptxt => 'Quit a bridged application or game.'
  ))

# !enter (lobby)
$cmdarray.push(Botcmd.new(
  :name => 'enter',
  :type => :public,
  :code => %q{
  begin
    unless $b.verify_user_db_entry(ujid)
      reply_user(ujid, "Setting your nickname to '#{$user_nicks[ujid]}'.  Use the !reserve command to select a new nickname.", $mtype)
    end
    if $lobby_users.include?(ujid)
      reply_user(ujid, "You are already in the lobby.", $mtype)
    elsif $bridged_users.include?(ujid)
      reply_user(ujid, "You must quit your bridged applicaion to enter the lobby.", $mtype)
    else
      $lobby_users.each do |user|
        reply_user(user, "#{$user_nicks[ujid]} has entered the lobby.", $mtype)
      end
      reply_user(ujid, "You've entered the lobby...", $mtype)
      $b.add_user_to_lobby(ujid)
      $db.execute("UPDATE roster SET in_lobby='1' WHERE rjid='" + ujid + "'")
      #$b.xmpp.status(nil, $b.get_status)
    end
  rescue Exception => e
    logit("Error (!enter): " + e.to_s)
    reply_user(ujid, "Error (!enter): " + e.to_s, $mtype)
  end
  },
  :return => nil,
  :helptxt => 'Enter the chat lobby.'
  ))

# !exit (lobby)
$cmdarray.push(Botcmd.new(
  :name => 'exit',
  :type => :public,
  :code => %q{
  begin
    if arg1
      reason = "#{arg1} #{arg2} #{arg3}"
      reason.strip!
      $b.leave_lobby(ujid, reason)
    else
      $b.leave_lobby(ujid, "!exit")
    end
    $db.execute("UPDATE roster SET in_lobby='0' WHERE rjid='" + ujid + "'")
  rescue Exception => e
    logit("Error (!leave): " + e.to_s)
    reply_user(ujid, "Error (!leave): " + e.to_s, $mtype)
  end
  },
  :return => nil,
  :helptxt => 'Exit the chat lobby.'
  ))


# !msg <jid> <msg>
$cmdarray.push(Botcmd.new(
  :name => 'msg',
  :type => :private,
  :code => %q{
    begin
      msgjid = arg1
      msgtxt = "#{arg2} #{arg3}"
      reply_user(ujid, "Sending msg to #{msgjid}", $mtype)
      reply_user(msgjid, msgtxt, $mtype)
    rescue Exception
      logit("Error (!msg): " + $!)
      reply_user(ujid, "Error: #{$!}", $mtype)
    end
  },
  :return => nil,
  :helptxt => 'Causes the bot to say the msg to the JID.'
  ))

# !link <search str>
$cmdarray.push(Botcmd.new(
  :name => 'link',
  :type => :private,
  :code => %q{
    begin
      if arg1==nil
        resultset = $db.query("SELECT data FROM info WHERE category='link' ORDER BY random() LIMIT 1")
      else
        resultset = $db.query("SELECT data FROM info WHERE category='link' AND data LIKE '%" + arg1 + "%'")
    end
      resultset.each do |row|
        reply_user(ujid, row[0].to_s, $mtype)
      end
      resultset.close
    rescue SQLite3::Exception #SQLite3::SQLException
      logit("SQLite3 Error (!link): " + $!)
      reply_user(ujid, "SQLite3: " + $!, $mtype)
    rescue Exception
      logit("Error (!link): " + $!)
      reply_user(ujid, "Error: " + $!, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'Print a list of matching links.'
  ))

# BE CAREFUL with this command!!!
# !sh <command>
$cmdarray.push(Botcmd.new(
  :name => 'sh',
  :type => :private,
  :code => %q{
  begin
    cmd = "#{arg1} #{arg2} #{arg3}"
    cmd_thread = Thread.new do
      reply_user(ujid, "running command: " + cmd, $mtype)
      output = `#{cmd} 2>&1`
      reply_user(ujid, output, $mtype)
    end
    cmd_thread.join(10)
  rescue Exception => e
    reply_user(ujid, "Error (!sh): " + e.to_s)
  end
  },
  :return => nil,
  :helptxt => 'Execute a non-interactive shell command.'
  ))

# !setstatus <msg>
$cmdarray.push(Botcmd.new(
  :name => 'setstatus',
  :type => :private,
  :code => %q{
  begin
    unless arg1
      reply_user(ujid, "usage: !setstatus <msg>", $mtype)
    else
      $b.status_msg = "#{arg1} #{arg2} #{arg3}"
      $b.xmpp.status(nil,$b.status_msg)
      reply_user(ujid, "Status msg set to: #{$b.status_msg}", $mtype)
    end
  rescue Exception => e
    reply_user(ujid, "Error (!setstatus): " + e.to_s, $mtype)
  end
  },
  :return => nil,
  :helptxt => 'Set the bot status message.'
  ))

# !addcontact <jid>
$cmdarray.push(Botcmd.new(
  :name => 'addcontact',
  :type => :private,
  :code => %q{
  begin
    authjid = arg1
    reply_user(ujid, "Sending auth request to #{authjid}...", $mtype)
    $b.xmpp.add(authjid)
  rescue Exception => e
    reply_user(ujid, "Error (!addcontact): " + e.to_s, $mtype)
  end
  },
  :return => nil,
  :helptxt => 'Add a contact to the bot roster.'
  ))

# !delcontact <jid>
$cmdarray.push(Botcmd.new(
  :name => 'delcontact',
  :type => :private,
  :code => %q{
  begin
    unless arg1
      reply_user(ujid, "usage: !delcontact <jid>", $mtype)
    else
      rmjid = arg1;
      $b.quit_bridged_app(rmjid)
      if $lobby_users.include?(rmjid)
        $b.leave_lobby(rmjid, "removed from roster")
      end
      reply_user(ujid, "Removing #{rmjid} as a contact.", $mtype)
      $b.xmpp.remove(rmjid)
      reply_user(ujid, "Removing #{rmjid} from roster table.", $mtype)
      $db.execute("DELETE FROM roster WHERE rjid = '#{rmjid}'")
      reply_user(ujid, "Removing #{rmjid} from $user_nicks hash.", $mtype)
      $user_nicks.delete(rmjid) 
      if $masters.include?(rmjid)
        reply_user(ujid, "Removing #{rmjid} from $masters array.", $mtype)
        $masters.delete(rmjid)
      end
      reply_user(ujid, "All done.", $mtype)
    end
  rescue Exception => e
    reply_user(ujid, "Error (!delcontact): " + e.to_s, $mtype)
  end
  },
  :return => nil,
  :helptxt => 'Delete a contact from the bot roster.'
  ))

# !listcontacts
$cmdarray.push(Botcmd.new(
  :name => 'listcontacts',
  :type => :private,
  :code => %q{
  begin
    reply_user(ujid, "Contact list:", $mtype)
    $b.xmpp.roster.items.each do |rjid,ritem|
      reply_user(ujid,rjid, $mtype)
    end
  rescue Exception => e
    reply_user(ujid, "Error (!listcontacts): " + e.to_s, $mtype)
  end
  },
  :return => nil,
  :helptxt => 'List contacts from the bot roster.'
  ))

# !broadcast <msg>
$cmdarray.push(Botcmd.new(
  :name => 'broadcast',
  :type => :private,
  :code => %q{
    begin
      unless arg1
        reply_user(ujid, "usage: !broadcast <msg>", $mtype)
      end
      msg = "#{arg1} #{arg2} #{arg3}"
      reply_user(ujid, "Sending msg to #{$b.xmpp.roster.items.length} contacts.", $mtype)
      logit("#{ujid} broadcasting msg to #{$b.xmpp.roster.items.length} contacts.")
      logit("Message = #{msg}")
      $b.xmpp.roster.items.each do |rjid,ritem|
        reply_user(rjid, msg, $mtype)
        sleep 0.1
      end
      reply_user(ujid, "Done sending.", $mtype)
    rescue Exception => e
      reply_user(ujid, "Error (!broadcast): " + e.to_s, $mtype)
      logit("Error (!broadcast): " + e.to_s + "\n" + e.backtrace.join)
    end
  },
  :return => nil,
  :helptxt => 'Broadcast message to all contacts.'
  ))

# !botroster
$cmdarray.push(Botcmd.new(
  :name => 'botroster',
  :type => :private,
  :code => %q{
    begin
      reply_user(ujid, "Listing #{$b.xmpp.roster.items.length} contacts:", $mtype)
      $b.xmpp.roster.items.each do |rjid,ritem|
        reply_user(ujid, "#{rjid}: #{ritem}", $mtype)
        sleep 0.1
      end
    rescue Exception => e
      reply_user(ujid, "Error (!botroster): " + e.to_s, $mtype)
      logit("Error (!botroster): " + e.to_s + "\n" + e.backtrace.join)
    end
  },
  :return => nil,
  :helptxt => 'List actual bot JID roster items.'
  ))


# !addadmin <jid> <nick> - add user to admin list
$cmdarray.push(Botcmd.new(
  :name => 'addadmin',
  :type => :private,
  :code => %q{
    newjid = arg1
    nick = arg2
    if nick == nil
      reply_user(ujid, "usage: !addadmin <jid> <nick>.", $mtype)
    elsif $user_nicks[newjid] != nick and $user_nicks.has_value?(nick)
      reply_user(ujid, "The nick '#{nick}' is already in use.", $mtype)
    elsif $masters.include?(newjid)
      reply_user(ujid, "#{newjid} is already an admin.", $mtype)
    else
      $masters << newjid
      begin
        # see if they are already in the db as a user
        found_jid = $db.get_first_value("SELECT rjid FROM roster WHERE rjid='" + newjid + "'")
        unless found_jid # if not there, add new record
          $db.execute("INSERT INTO roster (rjid,rlvl,rnick,rpasswd) VALUES ('" + newjid + "','admin','" + nick + "','" + passwd + "')")
        else # update existing record
          $db.execute("UPDATE roster SET rlvl='admin' WHERE rjid='" + newjid + "'")
        end
        reply_user(ujid,"#{newjid} is now an admin.", $mtype)
        $b.xmpp.add(newjid)
      rescue SQLite3::Exception #SQLite3::SQLException
        logit("SQLite3 Error (!addadmin): " + $!)
        reply_user(ujid, "SQLite3: " + $!, $mtype)
      rescue Exception
        logit("Error (!addadmin): " + $!)
        reply_user(ujid, "Error: " + $!, $mtype)
      end
    end
  },
  :return => nil,
  :helptxt => 'Add user (jid) to bot admin list.'
  ))

# !deladmin <jid> - remove user from admin list
$cmdarray.push(Botcmd.new(
  :name => 'deladmin',
  :type => :private,
  :code => %q{
    unless arg1
      reply_user(ujid, "usage: !deladmin <jid>", $mtype)
      return
    end
    adminjid = arg1
    if $masters.include?(adminjid)
      ulvl = $db.get_first_value("SELECT rlvl FROM roster WHERE rjid='" + adminjid + "'")
      if ulvl == 'owner'
        reply_user(ujid, "#{adminjid} is a bot owner and can't be removed.", $mtype)
      else
        $masters.delete(adminjid)
        begin
          #$db.execute("DELETE FROM roster WHERE rjid = '" + adminjid + "'")
          $db.execute("UPDATE roster SET rlvl='user' WHERE rjid='" + sql_sanitize(adminjid) + "'")
          reply_user(ujid, "#{adminjid} removed from the admin list.", $mtype)
        rescue SQLite3::Exception #SQLite3::SQLException
          logit("Error (!deladmin): " + $!)
          reply_user(ujid, "SQLite3: " + $!, $mtype)
        rescue Exception
          logit("Error (!deladmin): " + $!)
          reply_user(ujid, "Error: " + $!, $mtype)
        end
      end
    else
      reply_user(ujid, "#{adminjid} is not in the admin list.", $mtype)
    end
  },
  :return => nil,
  :helptxt => 'Delete user (jid) from bot admin list.'
  ))

# !about
$cmdarray.push(Botcmd.new(
  :name => 'about',
  :type => :public,
  :code => %q{
  begin
    reply_user(ujid,"==========================", $mtype)
    reply_user(ujid,"#{$product} v#{$version}", $mtype)
    reply_user(ujid,"==========================", $mtype)
    reply_user(ujid,"Author: Steve Gibson (steve@stevegibson.com)", $mtype)
    reply_user(ujid,"Website: http://www.stevegibson.com", $mtype)
    reply_user(ujid,"#{$product} was written in Ruby and uses:", $mtype)
    reply_user(ujid, "  Ruby v#{RUBY_VERSION}, XMPP4R, xmpp4r-simple,", $mtype)
    reply_user(ujid, "  SQLite, sqlite3-ruby", $mtype)
    reply_user(ujid,"==========================", $mtype)
    reply_user(ujid,"#{$product} administrators:", $mtype)
    $masters.each do |adminjid|
        reply_user(ujid, "--> #{adminjid}", $mtype)
    end
    reply_user(ujid,"==========================", $mtype)
  rescue Exception => e
    reply_user(ujid, "Error (!about): " + e.to_s)
  end
  },
  :return => nil,
  :helptxt => "About #{$product}."
  ))

# !help
$cmdarray.push(Botcmd.new(
  :name => 'help',
  :type => :public,
  :code => %q{
    begin
      reply_user(ujid, "---------- #{$product} commands -----------", $mtype)
      if arg1
        pattern = arg1
        reply_user(ujid, "[filtering on '#{pattern}']", $mtype)
      end
      if isbotmaster?(ujid)
        botmaster = true
      else
        botmaster = nil
      end
      helptext = Array.new
      sleep 0.05
      $cmdarray.each {|h|
        if pattern != nil
          if h.name.include?(pattern)
            if botmaster
              helptext << " !#{h.name} : #{h.helptxt}"
            else
              helptext << " !#{h.name} : #{h.helptxt}" if h.type == :public
            end
          end
        else
          if botmaster
            helptext << " !#{h.name} : #{h.helptxt}"
          else
            helptext << " !#{h.name} : #{h.helptxt}" if h.type == :public
          end
        end
      }

      helptext.sort!
      helptext.each do |txt|
         reply_user(ujid, txt.strip, $mtype)
         sleep 0.05
      end 
    rescue SQLite3::Exception #SQLite3::SQLException
      logit("Error (!help): " + $!)
      reply_user(ujid, "SQLite3: " + $!, $mtype)
    rescue Exception
      logit("Error (!help): " + $!)
      reply_user(ujid, "Error: " + $!, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'List this help message.'
  ))

# !last [count]
$cmdarray.push(Botcmd.new(
  :name => 'last',
  :type => :public,
  :code => %q{
    begin
      if arg1 == nil
        #arg1 = $lobby_msg_history.length
        arg1 = 20
      else 
        arg1 = arg1.to_i
      end
      i = arg1-1
      i.downto(0) do |x|
        reply_user(ujid, $lobby_msg_history[x], nil)
      end
    rescue Exception
      logit("Error (!last): " + $!)
      reply_user(ujid, "Error: " + $!, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'Print last [x] things said in the Lobby.'
  ))
