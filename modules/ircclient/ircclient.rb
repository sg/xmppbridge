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

class IRCclient

  attr_accessor :nick, :jid, :host, :port, :channel, :show_srv, :raw_mode, :channel_list,
                :version

  def initialize(ujid, host, port, nick)

    @version = "1.0"

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

    @thread = Thread.new do
      begin
        logit("#{self} created for #{@jid}.")
        reply_user(@jid, "XMPP-Bridge IRCClient v#{@version}", $mtype)
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
    reply_user(@jid, " .l <chan>  : Leave Channel", "std")
    reply_user(@jid, " .lc        : List Channels", "std")
    reply_user(@jid, " .c [chan#] : Change to chan #", "std")
    reply_user(@jid, " .s <msg>   : Send msg to server", "std")
    reply_user(@jid, " .n <nick>  : Set Nick", "std")
    reply_user(@jid, " .w <nick>  : Whois Nick", "std")
    reply_user(@jid, " .r         : Chan Roster", "std")
    reply_user(@jid, " .raw       : Raw Mode", "std")
    reply_user(@jid, " .p <nick> <msg> : Private Msg", "std")
    reply_user(@jid, " .quit [msg] : Quit (with msg)", "std")
    reply_user(@jid, " .h |.?     : This help msg", "std")
  end

  def send(msg)
    if msg.chomp == "QUIT"
      self.disconnect()
    else
      begin
        if msg.match(/^\.h.*$/)
          show_help

        elsif msg.match(/^\.\?$/)
          show_help 

        elsif msg.match(/^\.j (.+)$/)
          @sock.write("JOIN #{$1}\n")

        elsif msg.match(/^\.l (.+)$/)
          unless $1
            @sock.write("PART #{@channel}")
          else
            @sock.write("PART #{$1}\n")
          end

        elsif msg.match(/^\.lc$/)
          if @channel_list.length > 0
            reply_user(@jid, "List of active channels:", "std")
            @channel_list.each do |c|
              reply_user(@jid, "--> #{c}", "std")
            end
            reply_user(@jid, "Currently active on: '#{@channel}'", "std")
          else
            reply_user(@jid, "Not on any channels.  Use .j to join.", "std")
          end

        elsif msg.match(/^\.c (.+)$/)
          @channel = $1
          reply_user(@jid, "active channel now '#{@channel}'", "std")

        elsif msg.match(/^\.c$/)
          if @channel_list.length > 0
            i = 0
            @channel_list.each do |c|
              if c == @channel
                if i < (@channel_list.length - 1)
                  @channel = @channel_list[i+1]
                else
                  @channel = @channel_list[0]
                end
                break
              end
              i += 1
            end
            reply_user(@jid, "active channel now '#{@channel}'", "std")
          end

        elsif msg.match(/^\.s (.+)$/)
          @sock.write("#{$1}\n")
          reply_user(@jid, "sent to server: #{$1}", "std")

        elsif msg.match(/^\.n (.+)$/)
          @sock.write("NICK #{$1}\n")
          @nick = $1

        elsif msg.match(/^\.quit$/)
          @sock.write("QUIT :XMPP-Bridge v#{$version}\n")
          self.disconnect()

        elsif msg.match(/^\.quit (.+)$/)
          @sock.write("QUIT :#{$1}\n")
          self.disconnect()

        elsif msg.match(/^\.w (.+)$/)
          @sock.write("WHOIS #{$1}\n")

        elsif msg.match(/^\.r$/)
          @sock.write("NAMES #{@channel}\n")

        elsif msg.match(/^\.raw$/)
          if @raw_mode
            @raw_mode = false
            reply_user(@jid, "raw_mode = false", "std")
          else
            @raw_mode = true
            reply_user(@jid, "raw_mode = true", "std")
          end

        elsif msg.match(/^\.showsrv$/)
          if @show_srv
            @show_srv = false
            reply_user(@jid, "show_srv = false", "std")
          else
            @show_srv = true
            reply_user(@jid, "show_srv = true", "std")
          end
          
        elsif msg.match(/^\.p (.+?) (.+)$/)
          @sock.write("PRIVMSG #{$1} :#{$2}\n")

        else
          unless @channel == nil
            @sock.write("PRIVMSG #{@channel} :#{msg}\n")
            reply_user(@jid, "sent to: #{@channel}", "std")
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
    send(msgbody)
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

  private

  def send_to_user
    begin
    #@show_srv = true
    #@raw_mode = true
    msg_raw = @sock.gets
    msg = msg_raw
    unless msg == nil

        # try to clean up bytes that break things, in REXML I believe...
        # (we don't really need them anyway)
        msg = msg_raw.gsub(/\x01/,'*')
        msg = msg_raw.gsub(/[\x02-\x1F]|[\x7F-\xFF]/,'')
        
        if msg.match(/End of \/MOTD/)
          @show_srv = true
          reply_user(@jid, "*** End of MOTD -- now showing SRV messages.", "std")

        elsif msg.match(/^PING :(.+)/) 
          reply_user(@jid, msg.chomp, "std") if @raw_mode
          @sock.write("PONG #{$1}\n")
          reply_user(@jid, ">>> sent PONG to #{$1}", "std")

        elsif msg.match(/^:(.+?)!(.+?) NOTICE (.+?) :(.+)$/)
          notice_msg = "."
          if $3 == @nick
            notice_msg = "[NOTICE] #{$1}: #{$4}"
          else
            notice_msg = "[NOTICE #{$3}] #{$1}: #{$4}"
          end
          reply_user(@jid, msg.chomp, "std") if @raw_mode
          reply_user(@jid, notice_msg.chomp, "std")

        elsif msg.match(/^:(.+?)!(.+?) PRIVMSG (.+?) :.VERSION/)
          reply_user(@jid, msg.chomp, "std") if @raw_mode
          @sock.write("NOTICE #{$1} :XMPP Bridge v#{$version}")
          reply_user(@jid, ">>> sent CTCP VERSION reply to #{$1}", "std")

        elsif msg.match(/^:(.+?)!(.+?) PRIVMSG (.+?) :(.+)$/)
          priv_msg = "."
          if $3 == @nick
            priv_msg = "[PRIV]<#{$1}> #{$4}"
          else
            priv_msg = "[#{$3}]<#{$1}> #{$4}"
          end
          reply_user(@jid, msg.chomp, "std") if @raw_mode
          reply_user(@jid, priv_msg.chomp, "std")

        elsif msg.match(/^:(.+?)!(.+?) QUIT :(.*)$/)
          reason = $3.chomp
          quit_msg = "*** #{$1} disconnected (#{reason})"
          reply_user(@jid, msg.chomp, "std") if @raw_mode
          reply_user(@jid, quit_msg.chomp, "std")

        elsif msg.match(/^:(.+?)!(.+?) JOIN :(.+)$/)
          if $1 == @nick
            @channel = $3.chomp
            @channel_list << @channel
            reply_user(@jid, "active channel now '#{@channel}'", "std")
          end
          join_msg = "--> #{$1} joined #{$3}"
          reply_user(@jid, msg.chomp, "std") if @raw_mode
          reply_user(@jid, join_msg.chomp, "std")

        # freenode style PART
        elsif msg.match(/^:(.+?)!(.+?) PART (.+?) :(.*)$/)
          if $1 == @nick
            channel = $3
            if @channel_list.include?(channel)
              @channel_list.delete(channel)
              if channel == @channel
                if @channel_list.length > 0
                  @channel = @channel_list[@channel_list.length-1]
                  reply_user(@jid, "active channel now '#{@channel}'", "std")
                else
                  @channel = nil
                  reply_user(@jid, "no active channels", "std")
                end
              end
            end
          end
          part_msg = "<-- #{$1} left #{$3}: #{$4}"
          reply_user(@jid, msg.chomp, "std") if @raw_mode
          reply_user(@jid, part_msg.chomp, "std")

        # efnet style PART
        elsif msg.match(/^:(.+?)!(.+?) PART (.+)$/)
          if $1 == @nick
            channel = $3
            if @channel_list.include?(channel)
              @channel_list.delete(channel)
              if channel == @channel
                if @channel_list.length > 0
                  @channel = @channel_list[@channel_list.length-1]
                  reply_user(@jid, "active channel now '#{@channel}'", "std")
                else
                  @channel = nil
                  reply_user(@jid, "no active channels", "std")
                end
              end
            end
          end
          part_msg = "<-- #{$1} left #{$3}"
          reply_user(@jid, msg.chomp, "std") if @raw_mode
          reply_user(@jid, part_msg.chomp, "std")

        # undernet style PART
        elsif msg.match(/^:(.+?)!(.+?) PART :(.+)$/)
          if $1 == @nick
            channel = $3
            if @channel_list.include?(channel)
              @channel_list.delete(channel)
              if channel == @channel
                if @channel_list.length > 0
                  @channel = @channel_list[@channel_list.length-1]
                  reply_user(@jid, "active channel now '#{@channel}'", "std")
                else
                  @channel = nil
                  reply_user(@jid, "no active channels", "std")
                end
              end
            end
          end
          part_msg = "<-- #{$1} left #{$3}"
          reply_user(@jid, msg.chomp, "std") if @raw_mode
          reply_user(@jid, part_msg.chomp, "std")

        elsif msg.match(/^:(.+?)!(.+?) NICK :(.+)$/)
          nick_msg = "*** #{$1} is now known as #{$3}"
          reply_user(@jid, msg.chomp, "std") if @raw_mode
          reply_user(@jid, nick_msg.chomp, "std")

        # catch various server messages (using a 3-digit code)
        # and just display them as generic "SRV" messages.
        elsif msg.match(/^:(.+?)\.(.+?)\.(.+?) \d\d\d (.+?) (.+?)$/)
          srv_msg = "[SRV] #{$5}"
          if @show_srv
            reply_user(@jid, msg.chomp, "std") if @raw_mode
            reply_user(@jid, srv_msg.chomp, "std")
          end

        elsif msg.match(/^:(.+?) \d\d\d (.+?) :(.+)$/)
          reply_user(@jid, msg.chomp, "std") if @raw_mode
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
