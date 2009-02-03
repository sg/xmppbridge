#=====================================================
# GForth XMPPBridge module
#
# This module opens a connection to the gforth
# interpreter.
#
# Copyright 2009 by Steve Gibson
# steve@stevegibson.com (xmpp and email)
#
# This is free software.  You can redistribute it and/or
# modify it under the terms of the BSD license.  See
# LICENSE for more details.
#
#====================================================


require 'open3'

class GForthClient

  attr_reader :version

  def initialize(ujid)
    @jid = ujid

    @version = "1.0"

      @thread = Thread.new do

        begin
          logit("#{self} created for #{@jid}.")
          $lobby_users.each do |u|
            reply_user(u, "#{$user_nicks[@jid]} connected to GForth.", $mtype)
          end
          $bridges << self
          $bridged_users[@jid] = self # add to player=>bridged_app hash
          #$b.xmpp.status(nil,$b.get_status)

          # For some reason, grabbing stderr from the select call was
          # causing hangs when gforth would throw an exception.  So
          # instead I am just redirecting stderr to stdout via the
          # shell.
          @stdin, @stdout, @stderr = Open3.popen3("gforth 2>&1") 
          return_data = ""
          loop do
            while result = select([@stdout, @stderr], nil, nil, nil)
              for data in result[0]
                if data == @stdout
                  send_to_user(@stdout.gets)
                elsif data == @stderr
                  send_to_user(@stderr.gets)
                end
              end # for
            end # while
          end # loop

        rescue Exception => ex
          #reply_user(@jid, "gforthclient: " + ex.to_s, "std")
          logit("Error (GForthClient): #{@jid}: " + ex.to_s)
        end

      end # thread do
      @thread[:name] = "gforth:#{@jid}"
  end # initialize

  def send(msg)
    cmsg = msg.chomp
    if cmsg.downcase == "bye"
      self.disconnect()
    else
      begin
        @stdin.puts(cmsg)
      rescue Exception => e
        logit("GForthClient: Error writing to @stdin: " + e.to_s)
        reply_user(@jid, "GForthClient: Error writing to @stdin: " + e.to_s, "std")
      end
    end
  end

  def process_msg(ujid, msgtimestr, msgbody)
    # not doing any internal processing to this message.
    # just pass it on to the remote application.
    send(msgbody)
  end

  def disconnect(ujid=nil)
    begin
      @stdin.puts("bye")
      sleep 0.2
      reply_user(@jid, "terminating gforth thread...", "std")
      Thread.kill(@thread)
      reply_user(@jid, "Disconnected from GForth.", "std")
      $bridges.delete($bridged_users[@jid])
      $bridged_users.delete(@jid)
      logit("#{@jid} has disconnected from GForth.")
      reply_user(@jid, "Entering lobby...", "std")
      $lobby_users.each do |user|
        reply_user(user, "#{$user_nicks[@jid]} has exited GForth and entered the lobby.", "std") unless user == @jid
      end
      $b.add_user_to_lobby(@jid)
      #$b.xmpp.status(nil, $b.get_status)
    rescue Exception => e
      logit("Error (GForthClient::disconnect)" + e.to_s + "\n" + e.to_s)
      reply_user(@jid, "Error (GForthClient::disconnect): " + e.to_s)
    end
  end

  def type
    "gforth"
  end

  def info
    "gforth:" + @jid
  end

  private

  def send_to_user(msg)
    begin
      reply_user(@jid, msg.chomp, "std") if msg != nil
      #sleep 0.1
    rescue Exception => e
      logit("Error (GForthClient::send_to_user)" + e.to_s)
      reply_user(@jid, "Error (GForthClient::send_to_user): " + e.to_s)
    end  
  end

end

