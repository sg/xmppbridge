# encoding: iso-8859-1
#=====================================================
# IRC XMPPBridge module
#
# This module opens a tcp/ip connection to the specified
# IRC server.
#
# Copyright 2009 by Steve Gibson
# steve@stevegibson.com (xmpp and email)
#
# This is free software.  You can redistribute it and/or
# modify it under the terms of the BSD license.  See
# LICENSE for more details.
#
#====================================================

require 'socket'

include Socket::Constants

class IRCchannel
  attr_accessor :name, :roster, :topic
  def initialize(channel_name)
    @name = channel_name
    @roster = Hash.new()
    @topic = ""
  end

  def remove_user(user)
    self.roster.delete(user.nick)
  end

  def add_user(user)
    self.roster[user.nick] = user
  end
end

class IRCuser
  attr_accessor :nick, :op, :host, :realname
  def initialize(nick)
    @nick = nick
    @realname = ""
    @host = ""
    @op = false
  end

  def to_s
    self.nick
  end

  private
  def gethost 
    ""
  end
end

class IRCclient
  attr_accessor :nick, :jid, :host, :port, :channel, :show_srv, :raw_mode, :channel_list,
                :version, :ban_list
  def initialize(ujid, host, port, nick)
    @version = "1.1"
    @jid = ujid
    @host = host
    @port = port
    @user =  /^(.+)\@/.match(ujid)[1]
    @userhost =  /^(.+)\@(.+)$/.match(ujid)[2]
    @channel = nil
    @nick = nick
    @raw_mode = false
    @show_srv = false
    @channel_list = Array.new
    @muted_channel_list = Array.new
    @ban_list = Array.new

    @thread = Thread.new do
      begin
        logit("#{self} created for #{@jid}.")
        reply_user(@jid, "XMPP-Bridge IRCClient v#{@version}", $mtype)
        show_help()
        $lobby_users.each do |u|
          reply_user(u, "#{$user_nicks[@jid]} connected to IRC.", $mtype)
        end
        $bridges << self
        $bridged_users[@jid] = self # add to player=>bridged_app hash
        #$b.xmpp.status(nil,$b.get_status)

        @sock = TCPSocket.new(@host, @port)
        @sock.set_encoding("iso-8859-1") if RUBY_VERSION =~ /1\.9/
        login_thread = Thread.new do

          @sock.write("NICK #{@nick}\n")

          # if passing the @user instead of the @nick in the "USER" stanza
          # you need to sub out any "." since IRC doesn't like those in a
          # user name
          #@user.gsub!(".", "_")
          @sock.write("USER #{@nick} #{@userhost} {#@host} #{@nick}\n")

        end
        login_thread.join(10)
        login_thread.exit

        logit("IRCClient v#{@version} - #{@jid} connection successful.")
        loop do
          sleep 0.01
          result = select([@sock], nil, nil)
          if result != nil
            for inp in result[0]
              if inp == @sock
                send_to_user()
              end
            end
          end
        end
      rescue Exception => e
        reply_user(ujid, "Socket: " + e.to_s + "\n" + e.to_backtrace.join, "std")
      end
    end
    @thread[:name] = "irc:#{@jid}"
  end

  def show_help
    reply_user(@jid, "=== IRC Bridge Commands ===", "std")
    reply_user(@jid, " .j <chan>  : Join Channel", "std")
    reply_user(@jid, " .p <chan>  : Part Channel", "std")
    reply_user(@jid, " .lc        : List Channels", "std")
    reply_user(@jid, " .c [chan#] : Change to chan #", "std")
    reply_user(@jid, " .mute [name] : Mute chan", "std")
    reply_user(@jid, " .unmute <name> : UnMute chan", "std")
    reply_user(@jid, " .t <topic> : Set chan topic", "std")
    reply_user(@jid, " .s <msg>   : Send raw msg to server", "std")
    reply_user(@jid, " .n <nick>  : Set Nick", "std")
    reply_user(@jid, " .w <nick>  : Whois Nick", "std")
    reply_user(@jid, " .r         : Chan Roster", "std")
    reply_user(@jid, " .raw       : Recv raw msgs", "std")
    reply_user(@jid, " .m <nick> <msg> : Private Msg", "std")
    reply_user(@jid, " .k <nick> <msg> : Kick from channel", "std")
    reply_user(@jid, " .b <nick>  : Ban/Kick from channel", "std")
    reply_user(@jid, " .banlist   : List of bans", "std")
    reply_user(@jid, " .ub <num>  : Unban num (from list)", "std")
    reply_user(@jid, " .op <nick> : Make admin", "std")
    reply_user(@jid, " .deop <nick> : Remove admin", "std")
    reply_user(@jid, " .quit [msg] : Quit (with msg)", "std")
    reply_user(@jid, " .status    : Status info", "std")
    reply_user(@jid, " .h |.?     : This help msg", "std")
  end

  def status_info
    reply_user(@jid, "IRC Status:", "std")
    reply_user(@jid, "nick = #{@nick}", "std")
    channel_listing()
  end

  def channel_listing
    begin
      if @channel_list.length > 0
        reply_user(@jid, "List of active channels:", "std")
        count = 0
        @channel_list.each do |c|
          reply_user(@jid, "--> #{c.name}", "std")
        end
        reply_user(@jid, "Currently active on: '#{@channel.name}'", "std")
      else
        reply_user(@jid, "Not on any channels.  Use .j to join.", "std")
      end
      if @muted_channel_list.length > 0
        reply_user(@jid, "List of muted channels:", "std")
        count = 0
        @muted_channel_list.each do |c|
          reply_user(@jid, "--> #{c.name} [Muted]", "std")
        end
      end
    rescue Exception => ex
      reply_user(@jid, "Error (channel_listing): " + ex.to_s, "std")
    end
  end

  def change_active_channel(channel_name=nil)
    begin
      if channel_name
        found = false
        @channel_list.each do |c|
          if c.name == channel_name
            @channel = c
            found = true
          end
        end
        if found
          reply_user(@jid, "active channel now '#{@channel.name}'", "std")
        else
          reply_user(@jid, "you aren't joined to '#{channel_name}'", "std")
        end
      else
        if @channel_list.length > 0
          i = 0
          @channel_list.each do |c|
            if c.name == @channel.name 
              if i < (@channel_list.length - 1)
                @channel = @channel_list[i+1]
              else
                @channel = @channel_list[0]
              end
              break
            end
            i += 1
          end
          reply_user(@jid, "active channel now '#{@channel.name}'", "std")
        else
          reply_user(@jid, "Not on any channels.  Use .j to join.", "std")
        end
      end
    rescue Exception => ex
      reply_user(@jid, "Error (change_active_channel): " + ex.to_s, "std")
    end
  end

  def get_channel_roster
    begin
      if not @channel
        reply_user(@jid, "Not on any channels.  Use .j to join.", "std")
        return nil
      end
      usercount = 0
      opcount = 0
      userlist = ""
      users = Array.new
      @channel.roster.each do |k, v|
        if v.op
          users << "@#{v.nick}"
          opcount += 1
        else
          users << v.nick
          usercount += 1
        end
      end
      userlist = users.join(", ")
      reply_user(@jid, "[#{@channel.name}]: #{userlist}", "std")
      reply_user(@jid, "[#{@channel.name}]: #{usercount} users, #{opcount} ops", "std")
    rescue Exception => ex
      reply_user(@jid, "Error (get_channel_roster): " + ex.to_s, "std")
    end
  end

  def toggle_raw_mode
    begin
      if @raw_mode
        @raw_mode = false
        reply_user(@jid, "raw_mode = false", "std")
      else
        @raw_mode = true
        reply_user(@jid, "raw_mode = true", "std")
      end
    rescue Exception => ex
      reply_user(@jid, "Error (toggle_raw_mode): " + ex.to_s, "std")
    end
  end

  def toggle_showsrv_mode
    begin
      if @show_srv
        @show_srv = false
        reply_user(@jid, "show_srv = false", "std")
      else
        @show_srv = true
        reply_user(@jid, "show_srv = true", "std")
      end
    rescue Exception => ex
      reply_user(@jid, "Error (toggle_showsrv_mode): " + ex.to_s, "std")
    end
  end

  def mute_current_channel
    begin
      i = 0
      @channel_list.each do |c|
        if c.name == @channel.name 
          @muted_channel_list << c
          @channel_list.delete(c)
          if i < (@channel_list.length - 1)
            @channel = @channel_list[i+1]
          else
            @channel = @channel_list[0]
          end
          break
        end
        i += 1
      end
    rescue Exception => ex
      reply_user(@jid, "Error (mute_current_channel): " + ex.to_s, "std")
    end
  end

  def unmute_channel(channel_name)
    begin
      chan = get_channel_from_name(channel_name)
      if chan
        @channel_list << chan
        @muted_channel_list.delete(chan)
        reply_user(@jid, "*** Channel #{chan.name} unmuted", "std")
      else
        reply_user(@jid, "*** Couldn't find channel #{channel_name}", "std")
      end
    rescue Exception => ex
      reply_user(@jid, "Error (unmute_channel): " + ex.to_s, "std")
    end
  end

  def is_channel_op?(nick, channel_name)
    begin
      chan = get_channel_from_name(channel_name)
      if chan
        if chan.roster[nick.downcase].op
          return true
        end
      end
      return false
    rescue Exception => ex
      reply_user(@jid, "Error (is_channel_op?): " + ex.to_s, "std")
    end
  end

  def ban_exists?(ban_entry) # channame:banpattern
    begin
      retval = false
      @ban_list.each do |existing_ban|
        if ban_entry == existing_ban
          retval = true
          break
        end
      end
      retval
    rescue Exception => ex
      reply_user(@jid, "Error (ban_exists?): " + ex.to_s, "std")
    end
  end

  def send_who(nick)
    begin
      @sock.write("WHOIS #{nick}\n")
    rescue Exception => ex
      reply_user(@jid, "Error (send_who): " + ex.to_s, "std")
    end
  end

  def send_join(channel_name)
    begin
      @sock.write("JOIN #{channel_name}\n")
    rescue Exception => ex
      reply_user(@jid, "Error (send_join): " + ex.to_s, "std")
    end
  end

  def send_part(channel_name)
    begin
      @sock.write("PART #{channel_name}\n")
    rescue Exception => ex
      reply_user(@jid, "Error (send_part): " + ex.to_s, "std")
    end
  end

  def send_raw(msg)
    begin
      @sock.write("#{msg}\n")
      reply_user(@jid, "sent to server: #{msg}", "std")
    rescue Exception => ex
      reply_user(@jid, "Error (send_raw): " + ex.to_s, "std")
    end
  end

  def send_nick_change(newnick)
    begin
      @sock.write("NICK #{newnick}\n")
    rescue Exception => ex
      reply_user(@jid, "Error (send_nick_change): " + ex.to_s, "std")
    end
  end

  def send_private_msg(nick, msg)
    begin
      @sock.write("PRIVMSG #{nick} :#{msg}\n")
    rescue Exception => ex
      reply_user(@jid, "Error (send_private_msg): " + ex.to_s, "std")
    end
  end

  def send_kick(nick, msg=nil)
    begin
      msg = "channel admin" if not msg
      @sock.write("KICK #{@channel.name} #{nick} :#{msg}\n")
    rescue Exception => ex
      reply_user(@jid, "Error (send_kick): " + ex.to_s, "std")
    end
  end

  def send_ban(nick)
    begin
      unless @ban_list
        @ban_list = Array.new
      end
      nick.chomp!
      user = get_user_from_nick(nick)
      if user
        if user.host != ""
          ban_pattern = "*!~#{user.realname}@#{user.host}"
          ban_entry = "#{@channel.name}:#{ban_pattern}"
          if ban_exists?(ban_entry)
            reply_user(@jid, "*** Ban entry already exists!: #{ban_entry}" + ex.to_s, "std")
            return
          end
          @sock.write("MODE #{@channel.name} +b #{ban_pattern}\n")
          @ban_list << "#{@channel.name}:#{ban_pattern}"
          send_kick(nick, "banned")
        else
          ban_pattern = "#{nick}!~*@*"
          ban_entry = "#{@channel.name}:#{ban_pattern}"
          if ban_exists?(ban_entry)
            reply_user(@jid, "*** Ban entry already exists!: #{ban_entry}" + ex.to_s, "std")
            return
          end
          @sock.write("MODE #{@channel.name} +b #{ban_pattern}\n")
          @ban_list << "#{@channel.name}:#{ban_pattern}"
          send_kick(nick, "banned")
        end
      else
        reply_user(@jid, "*** Can't find nick: #{nick} -- ban failed", "std")
      end
    rescue Exception => ex
      reply_user(@jid, "Error (send_kick): " + ex.to_s, "std")
    end
  end

  def send_unban(num)
    begin
      if @ban_list.length == 0
        reply_user(@jid, "*** There are no bans in the list!", "std")
        return
      end
      bannum = num.chomp.to_i
      channame, banpattern = @ban_list[bannum].split(":")
      if is_channel_op?(@nick, channame)
        @sock.write("MODE #{channame} -b #{banpattern}\n")
        @ban_list.delete_at(bannum)
      else
        reply_user(@jid, "*** You are not a channel op for #{channame}.", "std")
      end
    rescue Exception => ex
      reply_user(@jid, "Error (send_unban): " + ex.to_s, "std")
    end
  end

  def send_list_channel_bans
    begin
      @sock.write("MODE #{@channel.name} -b\n")
    rescue Exception => ex
      reply_user(@jid, "Error (send_list_channel_bans): " + ex.to_s, "std")
    end
  end

  def handle_user_input(msg)
    if msg.chomp == "QUIT"
      self.disconnect()
    else
      begin
        if msg.match(/^\.h.*$/)
          show_help()

        elsif msg.match(/^\.\?$/)
          show_help() 

        elsif msg.match(/^\.j (.+)$/)
          send_join($1)

        elsif msg.match(/^\.p$/)
          send_part(@channel.name)

        elsif msg.match(/^\.p (.+)$/)
          send_part($1)

        elsif msg.match(/^\.lc$/)
          channel_listing()

        elsif msg.match(/^\.status$/)
          status_info()

        elsif msg.match(/^\.c (.+)$/)
          change_active_channel($1)

        elsif msg.match(/^\.c$/)
          change_active_channel()

        elsif msg.match(/^\.s (.+)$/)
          send_raw($1)

        elsif msg.match(/^\.n (.+)$/)
          send_nick_change($1)

        elsif msg.match(/^\.quit$/)
          @sock.write("QUIT :XMPP-Bridge IRC module v#{@version}\n")
          self.disconnect()

        elsif msg.match(/^\.quit (.+)$/)
          @sock.write("QUIT :#{$1}\n")
          self.disconnect()

        elsif msg.match(/^\.w (.+)$/)
          send_who($1)

        elsif msg.match(/^\.r$/)
          get_channel_roster()

        elsif msg.match(/^\.raw$/)
          toggle_raw_mode()

        elsif msg.match(/^\.showsrv$/)
          toggle_showsrv_mode()
 
        elsif msg.match(/^\.m (.+?) (.+)$/)
          send_private_msg($1, $2)

        elsif msg.match(/^\.mute$/)
          mute_current_channel()
 
        elsif msg.match(/^\.unmute (.+?)$/)
          unmute_channel($1)

        elsif msg.match(/^\.k (.+?) (.+?)$/)
          send_kick($1, $2)

        elsif msg.match(/^\.k (.+)$/)
          send_kick($1)

        elsif msg.match(/^\.b (.+)$/)
          send_ban($1)

        elsif msg.match(/^\.ub (.+)$/)
          send_unban($1)

        elsif msg.match(/^\.banlist$/)
          send_list_channel_bans()
          if @ban_list.length > 0
            count = 0
            @ban_list.each do |entry| 
              reply_user(@jid, "ban[#{count}] #{entry}", "std")
              count += 1
            end
          else
            reply_user(@jid, "No bans in the list.", "std")
          end
         

        elsif msg.match(/^\.op (.+)$/)
          @sock.write("MODE #{@channel.name} +o #{$1}\n")

        elsif msg.match(/^\.deop (.+)$/)
          @sock.write("MODE #{@channel.name} -o #{$1}\n")

        elsif msg.match(/^\.t (.+)$/)
          @sock.write("TOPIC #{@channel.name} :#{$1}\n")

        else
          unless @channel == nil
            @sock.write("PRIVMSG #{@channel.name} :#{msg}\n")
            reply_user(@jid, "sent to: #{@channel.name}", "std")
          else
            reply_user(@jid, "not active on a channel: use .c or .j", "std")
          end
        end

      rescue SocketError => se
        reply_user(@jid, "Socket error (send): " + se.to_s, "std")
      rescue Exception => ex
        reply_user(@jid, "Error (send): " + ex.to_s, "std")
      end
    end
  end

  def process_msg(ujid, msgtimestr, msgbody)
    # not doing any internal processing to this message.
    # just pass it on to the remote application.
    #reply_user(@jid, "got process_msg", "std")
    handle_user_input(msgbody)
  end

  def disconnect(ujid=nil)
    @sock.close
    Thread.kill(@thread)
    reply_user(@jid, "Disconnected from IRC.", "std")
    $bridges.delete($bridged_users[@jid])
    $bridged_users.delete(@jid)
    logit("#{@jid} has disconnected from IRC.")
    reply_user(@jid, "Entering lobby...", "std")
    $lobby_users.each do |user|
      reply_user(user, "#{$user_nicks[@jid]} has exited IRC and entered the lobby.", "std") unless user == @jid
    end
    $b.add_user_to_lobby(@jid)
    #$b.xmpp.status(nil, $b.get_status)
  end

  def using_ruby18?
    if RUBY_VERSION =~ /1\.8/
      return true
    else
      return false
    end
  end

  def type
    "irc"
  end

  def info
    "irc: " + @jid
  end

  def thread
    @thread
  end

  def sock
    @sock
  end

  def leave_channel(name)
    @channel_list.each do |c|
      if c.name == name
        @channel_list.delete(c)
      end
    end
    @muted_channel_list.each do |c|
      if c.name == name
        @channel_list.delete(c)
      end
    end
    if name == @channel.name
      if @channel_list.length > 0
        @channel = @channel_list[@channel_list.length-1]
        reply_user(@jid, "active channel now '#{@channel.name}'", "std")
      else
        @channel = nil
        reply_user(@jid, "no active channels", "std")
      end
    end
  end

  def get_user_from_nick(nick)
    lcasenick = nick.downcase
    @channel_list.each do |chan|
      if chan.roster.has_key?(lcasenick)
        return chan.roster[lcasenick]
      end
    end
    @muted_channel_list.each do |chan|
      if chan.roster.has_key?(lcasenick)
        return chan.roster[lcasenick]
      end
    end
    nil
  end

  def get_channel_from_name(channel_name)
    @channel_list.each do |chan|
      if chan.name == channel_name
        return chan
      end
    end
    @muted_channel_list.each do |chan|
      if chan.name == channel_name
        return chan
      end
    end
    nil
  end

  def remove_user_from_channel(channel_name, nick)
    lcasenick = nick.downcase
    @channel_list.each do |chan|
      if chan.name == channel_name
        chan.roster.delete(lcasenick)
        #reply_user(@jid, "removed #{nick} from #{chan.name} roster.", "std")
      end
    end
    @muted_channel_list.each do |chan|
      if chan.name == channel_name
        chan.roster.delete(lcasenick)
        #reply_user(@jid, "removed #{nick} from #{chan.name} roster.", "std")
      end
    end
  end

  # add_user_to_channel(channel_name, nick, realname, host)
  def add_user_to_channel(channel_name, nick, realname="", host="")
    op = false
    if nick.match(/^\@/) 
      nick.gsub!(/^[\@\+]/,'')
      op = true
    end
    user = IRCuser.new(nick)
    user.op = op
    user.realname = realname
    user.host = host
    @channel_list.each do |chan|
      if chan.name == channel_name
         n = nick.downcase
        chan.roster[n] = user
        #reply_user(@jid, "added #{nick} to #{chan.name} roster.", "std")
      end
    end
  end

  def update_nick_in_roster(old_nick, new_nick)
    lcaseold_nick = old_nick.downcase
    @channel_list.each do |chan|
      if chan.roster.has_key?(lcaseold_nick)
        user = chan.roster[lcaseold_nick]
        user.name = new_nick
        lcasenew_nick = new_nick.downcase
        chan.roster[lcasenew_nick] = user
        chan.roster.delete(lcaseold_nick)
        #reply_user(@jid, "updated #{old_nick} to #{new_nick} on #{chan.name}.", "std")
      end
    end
  end

  def send_to_user
    begin
    #@show_srv = true
    #@raw_mode = true
    msg_raw = @sock.gets
    msg = msg_raw
    unless msg == nil

        # try to clean up bytes that break things, in REXML I believe...
        # (we don't really need them anyway)
        msg.gsub!(/\x01/,'*')
        msg.gsub!(/[\x02-\x1F]|[\x7F-\xFF]/,'')
        
        reply_user(@jid, msg.chomp, "std") if @raw_mode

        if msg.match(/^PING :(.+)/) 
          @sock.write("PONG #{$1}\n")
          #reply_user(@jid, ">>> answered PING from #{$1}", "std")

        elsif msg.match(/^:(.+?)!(.+?) NOTICE (.+?) :(.+)$/)
          notice_msg = "."
          if $3 == @nick
            notice_msg = "[NOTICE] #{$1}: #{$4}"
          else
            notice_msg = "[NOTICE #{$3}] #{$1}: #{$4}"
          end
          reply_user(@jid, notice_msg.chomp, "std")

        elsif msg.match(/^:(.+?)!(.+?) PRIVMSG (.+?) :.VERSION/)
          @sock.write("NOTICE #{$1} :XMPP Bridge v#{$version}\n")
          reply_user(@jid, ">>> sent CTCP VERSION reply to #{$1}", "std")

        #:Olipro!~Olipro@uncyclopedia/olipro PRIVMSG #freenode :*ACTION pokes Tabmow with a goat*
        #elsif msg.match(/^:(.+?)!~?(.+?)@(.+?) PRIVMSG (.+?) :*ACTION (.+)*$/)
        #  priv_msg = "."
        #  if $4 == @nick
        #    priv_msg = "[PRIV] *#{$1} #{$5}"
        #  else
        #    chan = get_channel_from_name($4)
        #    if @channel_list.include?(chan)
        #      priv_msg = "[#{$4}] *#{$1} #{$5}*"
        #    end
        #  end
        #  reply_user(@jid, priv_msg, "std")

        elsif msg.match(/^:(.+?)!~?(.+?)@(.+?) PRIVMSG (.+?) :(.+)$/)
          priv_msg = "."
          if $4 == @nick
            priv_msg = "[PRIV]<#{$1}> #{$5}"
          else
            chan = get_channel_from_name($4)
            if @channel_list.include?(chan)
              priv_msg = "[#{$4}]<#{$1}> #{$5}"
            end
          end
          reply_user(@jid, priv_msg, "std")

        elsif msg.match(/^:(.+?)!(.+?) QUIT :(.*)$/)
          nick = $1
          channel_name = "no_channel"
          @channel_list.each do |chan|
            if chan.roster.has_key?(nick)
              chan.roster.delete(nick)
              channel_name = chan.name
              break
            end
          end
          @muted_channel_list.each do |chan|
            if chan.roster.has_key?(nick)
              chan.roster.delete(nick)
              channel_name = chan.name
              break
            end
          end
          reason = $3.chomp
          quit_msg = "*** #{$1} disconnected (#{reason})"
          reply_user(@jid, "#{quit_msg.chomp} [#{channel_name}]", "std")

        elsif msg.match(/^:(.+?)!~?(.+?)@(.+?) JOIN :(.+)$/)
          nick = $1
          realname = $2
          host = $3
          channel_name = $4.chomp
          if nick == @nick
            @channel = IRCchannel.new(channel_name)
            @channel_list << @channel
            reply_user(@jid, "active channel now '#{@channel.name}'", "std")
          else
            add_user_to_channel(channel_name, nick, realname, host)
          end
          join_msg = "--> #{nick} joined #{channel_name}"
          reply_user(@jid, join_msg.chomp, "std")

        # style1 PART
        elsif msg.match(/^:(.+?)!(.+?) PART (.+?) :(.*)$/)
          channel_name = $3.chomp
          if $1 == @nick
            leave_channel(channel_name)
          else
            remove_user_from_channel(channel_name, $1)
          end
          part_msg = "<-- #{$1} left #{$3}: #{$4}"
          reply_user(@jid, part_msg.chomp, "std")

        # style2 PART
        elsif msg.match(/^:(.+?)!(.+?) PART (.+?)$/)
          channel_name = $3.chomp
          if $1 == @nick
            leave_channel(channel_name)
          else
            remove_user_from_channel(channel_name, $1)
          end
          part_msg = "<-- #{$1} left #{$3}"
          reply_user(@jid, part_msg.chomp, "std")

        # style3 PART
        elsif msg.match(/^:(.+?)!(.+?) PART :(.+)$/)
          channel_name = $3.chomp
          if $1 == @nick
            leave_channel(channel_name)
          else
            remove_user_from_channel(channel_name, $1)
          end
          part_msg = "<-- #{$1} left #{$3}"
          reply_user(@jid, part_msg.chomp, "std")

        elsif msg.match(/^:(.+?)!(.+?) NICK :(.+)$/)
          old_nick = $1
          new_nick = $3
          if old_nick == @nick
            @nick = new_nick
          end
          update_nick_in_roster(old_nick, new_nick)
          nick_msg = "*** #{old_nick} is now known as #{new_nick}"
          reply_user(@jid, nick_msg.chomp, "std")

        # catch various server messages (using a 3-digit code)
        # and respond accordingly for some types, otherwise
        # just display them as generic "SRV" messages.
        elsif msg.match(/^:(.+?)\.(.+?)\.(.+?) (\d\d\d) (.+?) (.+?)$/)

          case $4

            when "376" # End of /MOTD 
              @show_srv = true
              reply_user(@jid, "*** End of MOTD -- now showing SRV messages.", "std")

            #:verne.freenode.net 367 SteveG #techforensics *!~SteveTest@dungeon.stevegibson.com SteveG!~SteveG@pdpc/supporter/21for7/steveg 1265394659
            when "367" # Channel bans list
              if msg.match(/^:(.+?) 367 (.+?) (.+?) (.+?) (.+?)$/)
                channame = $3
                ban_pattern = $4
                ban_value = "#{channame}:#{ban_pattern}"
                unless ban_exists?(ban_value)
                  @ban_list << ban_value
                  reply_user(@jid, "*** [load ban]: #{ban_value}", "std")
                end
              end  
            when "353" # Begin channel names list
              if msg.match(/^:(.+?)\.(.+?)\.(.+?) (\d\d\d) (.+?) . (.+?) :(.+?)$/)
                channame = $6
                chan = @channel
                @channel_list.each do |c|
                  if c.name == channame
                    chan = c
                  end
                end
                occupants_array = $7.split(' ')
                occupants_array.each do |nick|
                  add_user_to_channel(channame, nick)
                end
                reply_user(@jid, "*** [#{$6}] has #{chan.roster.length} users", "std")

                occupants = occupants_array.join(", ")
                reply_user(@jid, "*** [#{$6}] Occupants: #{occupants}", "std")
              else
                reply_user(@jid, "*** (regex mismatch) occupants: #{$6}", "std")
              end

            when "366" # End of /NAMES
              reply_user(@jid, "*** End of Occupant List", "std")

            when "332" # Channel topic
              if msg.match(/^:(.+?)\.(.+?)\.(.+?) (\d\d\d) (.+?) (.+?) :(.+?)$/)
                reply_user(@jid, "*** [#{$6}] Topic: #{$7}", "std")
              else
                reply_user(@jid, "*** (regex mismatch) Topic: #{$6}", "std")
              end

            else
              srv_msg = "[SRV] #{$6}"
              if @show_srv
                reply_user(@jid, srv_msg.chomp, "std")
              end

          end

        elsif msg.match(/^:(.+?)!~?(.+?)@(.+?) MODE (.+?) (.+?) (.+?)$/)
          nick = $1
          realname = $2
          host = $3
          channel_name = $4
          mode = $5
          target = $6 
          user = get_user_from_nick(target)
          if mode == "+o"
            user.op = true
          elsif mode == "-o"
            user.op = false
          end
          mode_msg = "*** [#{channel_name}] MODE #{mode} #{target} by #{nick}"
          reply_user(@jid, mode_msg.chomp, "std")

        elsif msg.match(/^:(.+?)\.(.+?)\.(.+?) MODE (.+?) (.+?)$/)
          reply_user(@jid, "*** [#{$4}] MODE #{$5}", "std")

        elsif msg.match(/^:(.+?)!(.+?) TOPIC (.+?) :(.+?)$/)
          topic_msg = "*** [#{$3}] #{$1} set TOPIC: #{$4}"
          reply_user(@jid, topic_msg.chomp, "std")

        elsif msg.match(/^:(.+?)!(.+?) KICK (.+?) (.+?) :(.+?)$/)
          if ($4 == @nick)
            kick_msg = "*** [#{$3}] You were KICKED by #{$1} (#{$5})"
            channel_name = $3
            leave_channel(channel_name)
            reply_user(@jid, kick_msg.chomp, "std")
            @sock.write("JOIN #{$3}\n")
          else
            kick_msg = "*** [#{$3}] KICKED #{$4} (#{$5})"
            reply_user(@jid, kick_msg.chomp, "std")
          end

        elsif msg.match(/^:(.+?) \d\d\d (.+?) :(.+)$/)
          reply_user(@jid, $3.chomp, "std") unless $3 == nil
        else
          reply_user(@jid, msg.chomp, "std")
        end
    else
      #reply_user(@jid, "_", "std")
    end
    rescue Exception => e
      reply_user(@jid, "Error (send_to_user): " + e.to_s + "\n" + e.backtrace.join, "std")
    end
  end

end
