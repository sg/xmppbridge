# encoding: iso-8859-1
#=======================================================
#  XMPPBridge module commands for mud
#
#  Copyright 2009 by Steve Gibson
#  steve@stevegibson.com (xmpp and email)
#
#  This is free software.  You can redistribute it and/or
#  modify it under the terms of the BSD license.  See
#  LICENSE for more details.
#
#=======================================================

# !mud
$cmdarray.push(Botcmd.new(
  :name => 'mud',
  :type => :public,
  :code => %q{
    begin
      player = ujid
      if $bridged_users.include?(player)
        reply_user(player, "You are already bridged.  Use !quit first if you want to join or create a new bridge to another application or game.", $mtype)
      else
        leave_lobby(player, "connecting to MUD")
        reply_user(player, "Connecting to MUD...", $mtype)
        logit("#{player} connecting to MUD...")
        mud = MUDclient.new(player, 'tower.stevegibson.com', 4444)
      end
    rescue Exception => e
      reply_user(ujid, "Error (!testmud): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'Connect to Sandbox MUD.'
  ))

