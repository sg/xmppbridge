# encoding: iso-8859-1
#=======================================================
#  XMPPBridge module commands for mushclient
#
#  Copyright 2009 by Steve Gibson
#  steve@stevegibson.com (xmpp and email)
#
#  This is free software.  You can redistribute it and/or
#  modify it under the terms of the BSD license.  See
#  LICENSE for more details.
#
#=======================================================

# !pennmush
$cmdarray.push(Botcmd.new(
  :name => 'pennmush',
  :type => :public,
  :code => %q{
    begin
      player = ujid
      if $bridged_users.include?(player)
        reply_user(player, "You are already bridged.  Use !quit first if you want to join or create a new bridge to another application or game.", $mtype)
      else
        leave_lobby(player, "connecting to PennMUSH")
        reply_user(player, "Connecting to PennMUSH...", $mtype)
        logit("#{player} connecting to PennMUSH...")
        mush = MUSHclient.new(player, 'mush.pennmush.org', 4201)
      end
    rescue Exception => e
      reply_user(ujid, "Error (!pennmush): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'Connect to PennMUSH.'
  ))

# !mush
$cmdarray.push(Botcmd.new(
  :name => 'mush',
  :type => :public,
  :code => %q{
    begin
      player = ujid
      if $bridged_users.include?(player)
        reply_user(player, "You are already bridged.  Use !quit first if you want to join or create a new bridge to another application or game.", $mtype)
      else
        leave_lobby(player, "connecting to MUSH")
        reply_user(player, "Connecting to the MUSH...", $mtype)
        logit("#{player} connecting to the MUSH...")
        mush = MUSHclient.new(player, 'tower.stevegibson.com', 4201)
      end
    rescue Exception => e
      reply_user(ujid, "Error (!mush): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'Connect to Sandbox MUSH.'
  ))
