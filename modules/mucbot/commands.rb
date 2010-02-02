# encoding: iso-8859-1
#=======================================================
#  XMPP Bridge module commands for mucbot 
#
#  Copyright 2009 by Steve Gibson
#  steve@stevegibson.com (xmpp and email)
#
#  This is free software.  You can redistribute it and/or
#  modify it under the terms of the BSD license.  See
#  LICENSE for more details.
#
#=======================================================

# !mucjoin <room_jid> [botnick] [password]
$cmdarray.push(Botcmd.new(
  :name => 'mucjoin',
  :type => :private,
  :code => %q{
  if arg1 == nil
    reply_user(ujid, "usage: !mucjoin <room_jid> [botnick] [password]", $mtype)
  else
    room_jid = arg1
    if arg2 == nil
      botnick = $botnick
    else
      botnick = arg2
    end
    if arg3 == nil
      password = nil
    else
      password = arg3
    end
    room_alias = /^(.+)\@/.match(room_jid)[1]
    begin
      mucbot = MUCBot.new(
        :room_jid => room_jid,
        :botnick => botnick,
        :auto_rejoin => true,
        :allow_public_commands => true,
        :password => password,
        :room_alias => room_alias
      )
      mucbot.monitors << ujid
      $mucbot_array = Array.new unless $mucbot_array
      $mucbot_array << mucbot
    rescue Exception => e
      reply_user(ujid, "Error (!mucjoin): " + e.to_s, $mtype)
    end
  end
  },
  :return => nil,
  :helptxt => 'Connect to a muc/chatroom.'
  ))

# !mucobj
$cmdarray.push(Botcmd.new(
  :name => 'mucobj',
  :type => :private,
  :code => %q{
    begin
      count = ObjectSpace.each_object(MUCBot) do |m|
        reply_user(ujid, "muc_number:" + m.muc_number.to_s + " alias:" + m.room_alias + " obj: " + m.to_s, $mtype)
      end
      reply_user(ujid, "MUCBot count: " + count.to_s, $mtype)
    rescue Exception => e
      reply_user(ujid, "Error (!mucobj): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'List MUCBot objects in ObjectSpace.'
  ))

# !s <muc_number>
$cmdarray.push(Botcmd.new(
  :name => 's',
  :type => :private,
  :code => %q{
  if arg1 == nil
    reply_user(ujid, "usage: !s <muc_number> <msg>", $mtype)
  else
    muc_num = arg1
    msg = "#{arg2} #{arg3}"
    begin
      found_muc = false
      ObjectSpace.each_object(MUCBot) do |m|
        if m.muc_number.to_s == muc_num
          m.mucbot.say(msg)
          found_muc = true
          break
        end
      end
      unless found_muc
        reply_user(ujid, "No such muc number found.  Try !muclist.", $mtype)
      end
    rescue Exception => e
      reply_user(ujid, "Error (!s): " + e.to_s, $mtype)
    end
  end
  },
  :return => nil,
  :helptxt => 'Say msg to muc_number (i.e., !s 2 test message).'
  ))

# !p <muc_number> <nick>
$cmdarray.push(Botcmd.new(
  :name => 'p',
  :type => :private,
  :code => %q{
  unless arg1 && arg2 && arg3
    reply_user(ujid, "usage: !p <muc_number> <nick> <msg>", $mtype)
  else
    muc_num = arg1
    to_nick = arg2
    msg = "#{arg3}"
    begin
      found_muc = false
      ObjectSpace.each_object(MUCBot) do |m|
        if m.muc_number.to_s == muc_num
          if m.chatroom_roster.include?(to_nick)
            m.mucbot.say(msg, to_nick)
            reply_user(ujid, "(sent to #{to_nick})", $mtype)
          else
            reply_user(ujid, "No such nick in that MUC.", $mtype)
          end
          found_muc = true
          break
        end
      end
      unless found_muc
        reply_user(ujid, "No such muc number found.  Try !muclist.", $mtype)
      end
    rescue Exception => e
      reply_user(ujid, "Error (!p): " + e.to_s, $mtype)
    end
  end
  },
  :return => nil,
  :helptxt => 'Say priv msg to nick in muc (i.e., !p 2 nick message).'
  ))

# !mucleave <muc_number>
$cmdarray.push(Botcmd.new(
  :name => 'mucleave',
  :type => :private,
  :code => %q{
  if arg1 == nil
    reply_user(ujid, "usage: !mucleave <muc_number>", $mtype)
  else
    muc_num = arg1
    begin
      found_muc = false
      ObjectSpace.each_object(MUCBot) do |m|
        if m.muc_number.to_s == muc_num
          m.disconnect
          $mucbot_array.delete(m)
          m = nil
          found_muc = true
          break
        end
      end
      unless found_muc
        reply_user(ujid, "No such muc number found.  Try !muclist.", $mtype)
      end
    rescue Exception => e
      reply_user(ujid, "Error (!mucdel): " + e.to_s, $mtype)
    end
  end
  },
  :return => nil,
  :helptxt => 'Leave a muc/chatroom.'
  ))

# !mucdel <muc_number>
$cmdarray.push(Botcmd.new(
  :name => 'mucdel',
  :type => :private,
  :code => %q{
  if arg1 == nil
    reply_user(ujid, "usage: !mucdel <muc_number>", $mtype)
  else
    muc_num = arg1
    begin
      found_muc = false
      ObjectSpace.each_object(MUCBot) do |m|
        if m.muc_number.to_s == muc_num
          m.disconnect
          $mucbot_array.delete(m)
          m = nil
          found_muc = true
          break
        end
      end
      unless found_muc
        reply_user(ujid, "No such muc number found.  Try !muclist.", $mtype)
      end
    rescue Exception => e
      reply_user(ujid, "Error (!mucdel): " + e.to_s, $mtype)
    end
  end
  },
  :return => nil,
  :helptxt => 'Delete a muc room.'
  ))

# !muclist
$cmdarray.push(Botcmd.new(
  :name => 'muclist',
  :type => :private,
  :code => %q{
    begin
      reply_user(ujid, "Connected to rooms:", $mtype)
      ObjectSpace.each_object(MUCBot) do |m|
        reply_user(ujid, "[#{m.muc_number}]#{m.room_jid}: nick=#{m.botnick}", $mtype)
      end
    rescue Exception => e
      reply_user(ujid, "Error (!muclist): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'List connected chatrooms.'
  ))

# !mucmon <muc_number>
$cmdarray.push(Botcmd.new(
  :name => 'mucmon',
  :type => :private,
  :code => %q{
  if arg1 == nil
    reply_user(ujid, "usage: !mucmon <muc_number>", $mtype)
  else
    muc_num = arg1
    begin
      found_muc = false
      ObjectSpace.each_object(MUCBot) do |m|
        if m.muc_number.to_s == muc_num
          if m.monitors.include?(ujid)
            reply_user(ujid, "You are already monitoring [#{m.muc_number}]#{m.room_alias} (#{m.room_jid})", $mtype)
          else
            m.monitors << ujid
            reply_user(ujid, "You are now monitoring [#{m.muc_number}]#{m.room_alias} (#{m.room_jid})", $mtype)
          end
          found_muc = true
          break
        end
      end
      unless found_muc
        reply_user(ujid, "No such muc number found.  Try !muclist.", $mtype)
      end
    rescue Exception => e
      reply_user(ujid, "Error (!mucmon): " + e.to_s, $mtype)
    end
  end
  },
  :return => nil,
  :helptxt => 'Monitor a muc/chatroom.'
  ))

# !mucunmon <muc_number>
$cmdarray.push(Botcmd.new(
  :name => 'mucunmon',
  :type => :private,
  :code => %q{
  if arg1 == nil
    reply_user(ujid, "usage: !mucunmon <muc_number>", $mtype)
  else
    muc_num = arg1
    begin
      found_muc = false
      ObjectSpace.each_object(MUCBot) do |m|
        if m.muc_number.to_s == muc_num
          if m.monitors.include?(ujid)
            m.monitors.delete(ujid)
            reply_user(ujid, "You are no longer monitoring [#{m.muc_number}]#{m.room_alias} (#{m.room_jid})", $mtype)
          else
            reply_user(ujid, "You weren't monitoring [#{m.muc_number}]#{m.room_alias} (#{m.room_jid})", $mtype)
          end
          found_muc = true
          break
        end
      end
      unless found_muc
        reply_user(ujid, "No such muc number found.  Try !muclist.", $mtype)
      end
    rescue Exception => e
      reply_user(ujid, "Error (!mucunmon): " + e.to_s, $mtype)
    end
  end
  },
  :return => nil,
  :helptxt => 'Un-monitor a muc/chatroom.'
  ))

# !mucroster <muc_number>
$cmdarray.push(Botcmd.new(
  :name => 'mucroster',
  :type => :private,
  :code => %q{
  if arg1 == nil
    reply_user(ujid, "usage: !mucroster <muc_number>", $mtype)
  else
    muc_num = arg1
    begin
      found_muc = false
      ObjectSpace.each_object(MUCBot) do |m|
        if m.muc_number.to_s == muc_num
          reply_user(ujid, "Room roster for #{m.room_jid}:", $mtype)
          m.mucbot.roster.each do |nick,pres|
            pres_item=pres.x("http://jabber.org/protocol/muc#user").first_element("item").to_s
            role=pres_item.match(/role='(\w+)'/)[1]
            aff=pres_item.match(/affiliation='(\w+)'/)[1]
            reply_user(ujid, nick + ": " + role + " (" + aff + ")", $mtype)
          end
          reply_user(ujid, m.mucbot.roster.length.to_s + " users.", $mtype)
          found_muc = true
          break
        end
      end
      unless found_muc
        reply_user(ujid, "No such muc number found.  Try !muclist.", $mtype)
      end
    rescue Exception => e
      reply_user(ujid, "Error (!mucroster): " + e.to_s, $mtype)
    end
 end
 },
 :return => nil,
 :helptxt => 'List muc room users'
 ))
