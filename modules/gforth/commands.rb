#=======================================================
#  XMPP Bridge module commands for GForth
#
#  Copyright 2009 by Steve Gibson
#  steve@stevegibson.com (xmpp and email)
#
#  This is free software.  You can redistribute it and/or
#  modify it under the terms of the BSD license.  See
#  LICENSE for more details.
#
#=======================================================

# !gforth
$cmdarray.push(Botcmd.new(
  :name => 'gforth',
  :type => :private,
  :code => %q{
    begin
      player = ujid
      if $bridged_users.include?(player)
        reply_user(player, "You are already bridged.  Use !quit first if you want to join or create a new bridge to another application or game.", $mtype)
      else
        leave_lobby(player, "connecting to GForth")
        reply_user(player, "Connecting to GForth...", $mtype)
        
        logit("#{player} connecting to GForth...")
        f = GForthClient.new(player)
      end
    rescue Exception => e
      reply_user(ujid, "Error (!gforth): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'Connect to a gforth interpreter'
  ))
