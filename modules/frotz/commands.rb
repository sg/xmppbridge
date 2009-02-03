#=======================================================
#  XMPP Bridge module commands for frotz 
#
#  Copyright 2009 by Steve Gibson
#  steve@stevegibson.com (xmpp and email)
#
#  This is free software.  You can redistribute it and/or
#  modify it under the terms of the BSD license.  See
#  LICENSE for more details.
#
#=======================================================

# !frotzhelp
$cmdarray.push(Botcmd.new(
  :name => 'frotzhelp',
  :type => :public,
  :code => %q{
  begin
    reply_user(ujid, "***************************", $mtype)
    reply_user(ujid, "* Frotz Help (!frotzhelp) *", $mtype)
    reply_user(ujid, "*                         *", $mtype)
    reply_user(ujid, "* Sending special chars:  *", $mtype)
    reply_user(ujid, '* \_ = RETURN (by itself) *', $mtype)
    reply_user(ujid, '* \U = undo one turn      *', $mtype)
    reply_user(ujid, "*                         *", $mtype)
    reply_user(ujid, "* Special commands:       *", $mtype)
    reply_user(ujid, "* QUIT = quit the game    *", $mtype)
    reply_user(ujid, "* SAVE = save the game    *", $mtype)
    reply_user(ujid, "* RESTORE = restore saved *", $mtype)
    reply_user(ujid, "*                         *", $mtype)
    reply_user(ujid, "***************************", $mtype)
  rescue Exception => e
    reply_user(ujid, "Error (!frotzhelp): " + e.to_s)
  end
  },
  :return => nil,
  :helptxt => 'Print help message for frotz.'
  ))

# !frotzlist
$cmdarray.push(Botcmd.new(
  :name => 'frotzlist',
  :type => :public,
  :code => %q{
  begin
    zgames = Array.new
    Dir.foreach("modules/frotz/zgames") do |filename|
      if filename.include?(".z5")
        filename.gsub!(/\.z5/,'')
        zgames << filename
      end
    end
    zgames.sort!
    zgames.each do |zgame|
      if zgame.include?("priv-")
        next unless isbotmaster?(ujid)
      end
      reply_user(ujid, "  #{zgame}", $mtype)
    end
  rescue Exception => e
    reply_user(ujid, "Error (!frotzlist): " + e.to_s)
  end
  },
  :return => nil,
  :helptxt => 'Lists z-games available via !frotz.'
  ))

# !frotz <game> <screen_width>
$cmdarray.push(Botcmd.new(
  :name => 'frotz',
  :type => :public,
  :code => %q{
    begin
      if arg1 == nil
        zgame = "edifice"
      else
        zgame = arg1
      end
      if arg2 == nil
        width = "80"
      else
        width = arg2.to_s
        if width.match(/\;|\/|[a-z]|[A-Z]/)
          raise "invalid width specified"
        end
      end
      player = ujid
      if $bridged_users.include?(player)
        reply_user(player, "You are already bridged.  Use !quit first if you want to join or create a new bridge to another application or game.", $mtype)
      else
        leave_lobby(player, "connecting to Frotz")
        logit("#{player} connecting to Frotz (#{zgame})...")
        f = FrotzClient.new(player, zgame, width)
      end
    rescue Exception => e
      reply_user(ujid, "Error (!frotz): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'Connect to a z-game. (e.g.,  !frotz zork1 [scrn_width] )'
  ))
