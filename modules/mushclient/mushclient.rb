# encoding: iso-8859-1
#=====================================================
# MUSHclient XMPPBridge module
#
# This module opens a tcp/ip connection to the specified
# MUSH server.
#
#  Copyright 2009 by Steve Gibson
#  steve@stevegibson.com (xmpp and email)
#
#  This is free software.  You can redistribute it and/or
#  modify it under the terms of the BSD license.  See
#  LICENSE for more details.
#
#====================================================

require 'socket'

include Socket::Constants

class MUSHclient

  attr_reader :version

  def initialize(ujid, host, port)

    @version = "1.1"

    @jid = ujid
    @host = host
    @port = port

    @thread = Thread.new do
      begin
        logit("#{self} created for #{@jid}.")
        logit("MUSHclient v#{@version} - #{@jid} connection successful.")
        reply_user(@jid, "XMPP-Bridge MUSHclient v#{@version}", $mtype)
        $lobby_users.each do |u|
          reply_user(u, "#{$user_nicks[@jid]} connected to the MUSH.", $mtype)
        end
        $bridges << self
        $bridged_users[@jid] = self # add to player=>bridged_app hash
        #$b.xmpp.status(nil,$b.get_status)

        @sock = TCPSocket.new(@host, @port)
        @sock.set_encoding("iso-8859-1") if RUBY_VERSION =~ /1\.9/
        loop do
          sleep 0.1
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
        reply_user(@jid, "Socket: " + e.to_s + "\n" + e.backtrace.join, "std")
      end
    end
    @thread[:name] = "mush:#{@jid}"
  end

  def send(msg)
    if msg.chomp == "QUIT"
      self.disconnect()
    else
      begin
        msg.gsub!(/\&lt;/, '<') # convert to real less-thans
        # 0x41-0x5a
        #m = msg.match(/^[A-Z]/)[0]
        msg.gsub!(/\&gt;/, '>') # convert to real greater-thans
        msg.gsub!(/\&amp;/, '&') # convert to real ampersand
        @sock.write(msg + "\n")
      rescue SocketError => se
        reply_user(@jid, "Socket error (send): " + se.to_s, "std")
        logit("Socket error (send): " + se.to_s)
        disconnect(@jid)
      rescue Exception => ex
        reply_user(@jid, "Error (send): " + ex.to_s, "std")
        logit("Error (send): " + ex.to_s)
        disconnect(@jid)
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
    reply_user(@jid, "Disconnected from MUSH.", "std")
    $bridges.delete($bridged_users[@jid])
    $bridged_users.delete(@jid)
    logit("#{@jid} has exited the MUSH client.")
    reply_user(@jid, "Entering lobby...", "std")
    $lobby_users.each do |user|
      reply_user(user, "#{$user_nicks[@jid]} has exited the MUSH and entered the lobby.", "std") unless user == @jid
    end
    $b.add_user_to_lobby(@jid)
    #$b.xmpp.status(nil, $b.get_status)
  end

  def type
    "mush"
  end

  def info
    "mush: " + @jid
  end

  private

  def send_to_user
    msg = @sock.gets
    unless msg == nil

      # try to clean up bytes that break things, in REXML I believe...
      # (we don't really need them anyway)
      msg.gsub!(/\x01/,'*')
      msg.gsub!(/[\x02-\x1F]|[\x7F-\xFF]/,'')

      # strip/replace escape codes 
      msg.gsub!(/\[\d\d?;\d\d?;\d\d?\w/,'')
      msg.gsub!(/\[\d\d?;\d\d?\w/,'')
      msg.gsub!(/\[\d\d?\w/,'')

      reply_user(@jid, msg.chomp, "std")

    else
      #reply_user(@jid, "_", "std")
    end
  end

end
