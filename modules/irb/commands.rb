#=======================================================
#  XMPP Bridge module commands for IRB
#
#  Copyright 2009 by Steve Gibson
#  steve@stevegibson.com (xmpp and email)
#
#  This is free software.  You can redistribute it and/or
#  modify it under the terms of the BSD license.  See
#  LICENSE for more details.
#
#=======================================================

# !irb
$cmdarray.push(Botcmd.new(
  :name => 'irb',
  :type => :private,
  :code => %q{
    begin
      user = ujid

      irb_ver = nil
      if arg1 == nil
        irb_ver = "18"
      elsif arg1 == "19"
        irb_ver = arg1
      elsif arg1 == "18"
        irb_ver = arg1
      else
        reply_user(user, "usage: irb [18|19]", $mtype)
        return
      end

      if $bridged_users.include?(user)
        reply_user(user, "You are already bridged.  Use !quit first if you want to join or create a new bridge to another application or game.", $mtype)
      else
        leave_lobby(user, "connecting to irb")
        reply_user(user, "Connecting to irb...", $mtype)
        
        logit("#{user} connecting to irb...")
        irb = IRBClient.new(user, irb_ver)
      end
    rescue Exception => e
      reply_user(ujid, "Error (!irb): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'Connect to irb'
  ))
