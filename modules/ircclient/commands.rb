# encoding: iso-8859-1
#=======================================================
#  XMPP Bridge module commands for irc 
#
#  Copyright 2009 by Steve Gibson
#  steve@stevegibson.com (xmpp and email)
#
#  This is free software.  You can redistribute it and/or
#  modify it under the terms of the BSD license.  See
#  LICENSE for more details.
#
#=======================================================

# !irc-freenode
$cmdarray.push(Botcmd.new(
  :name => 'irc-freenode',
  :type => :public,
  :code => %q{
    begin
      if arg1 == nil
        reply_user(ujid, "usage: !irc-freenode <nick>", $mtype)
      else   
        nick = arg1
        if $bridged_users.include?(ujid)
          reply_user(ujid, "You are already bridged.  Use !quit first if you want to join or create a new bridge to another application or game.", $mtype)
        else
          $b.leave_lobby(ujid, "connecting to irc.freenode.net")
          reply_user(ujid, "Connecting to irc.freenode.net...", $mtype)
          logit("#{ujid} connecting to irc.freenode.net...")
          irc = IRCclient.new(ujid, "irc.freenode.net", 6667, nick)
        end
      end
    rescue Exception => e
      reply_user(ujid, "Error (!irc-freenode): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'start irc session to freenode.net.'
  ))

# !irc
$cmdarray.push(Botcmd.new(
  :name => 'irc',
  :type => :private,
  :code => %q{
    begin
      if arg1 == nil or arg2 == nil
        reply_user(ujid, "usage: !irc <host> <port> [nick]", $mtype)
      else   
        if arg3 == nil
          nick = $user_nicks[ujid]
        else
          nick = arg3
        end
        if $bridged_users.include?(ujid)
          reply_user(ujid, "You are already bridged.  Use !quit first if you want to join or create a new bridge to another application or game.", $mtype)
        else
          leave_lobby(ujid, "connecting to irc")
          reply_user(ujid, "Connecting to #{arg1}...", $mtype)
          logit("#{ujid} connecting to #{arg1}...")
          irc = IRCclient.new(ujid, arg1, arg2, nick)
        end
      end
    rescue Exception => e
      reply_user(ujid, "Error (!irc): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'start irc session to host and port.'
  ))

