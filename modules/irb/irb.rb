#=====================================================
# irb XMPPBridge module
#
# This module opens a connection to the interactive
# ruby interpreter.
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

class IRBClient

  attr_reader :version

  def initialize(ujid, irb_ver="18")
    @jid = ujid
    @irb_ver = irb_ver
    @version = "1.0"
    @cmd_count = 0
    @user_input = ""

      @thread = Thread.new do

        begin
          logit("#{self} created for #{@jid}.")
          $lobby_users.each do |u|
            reply_user(u, "#{$user_nicks[@jid]} connected to irb.", $mtype)
          end
          $bridges << self
          $bridged_users[@jid] = self # add to user=>bridged_app hash
          #$b.xmpp.status(nil,$b.get_status)
        
          if @irb_ver == "19"
            @stdin, @stdout, @stderr = Open3.popen3("irb1.9.0") 
          else
            @stdin, @stdout, @stderr = Open3.popen3("irb") 
          end

          send_to_user("[irb:#{@cmd_count}>")
          loop do
            while result = select([@stdout, @stderr], nil, nil, 0.05)
              for data in result[0]
                if data == @stderr
                  #send_to_user(@stderr.gets)
                  #send_to_user("[irb:#{@cmd_count}>")
                elsif data == @stdout
                  sout = @stdout.gets
                  unless sout.chomp == @user_input || sout.chomp == ""
                    send_to_user(sout)
                    send_to_user("[irb:#{@cmd_count}>")
                  end
                end
              end # for
            end # while
          end # loop

        rescue Exception => ex
          #reply_user(@jid, "irbclient: " + ex.to_s, "std")
          logit("Error (IRBClient): #{@jid}: " + ex.to_s)
        end

      end # thread do
      @thread[:name] = "irb:#{@jid}"
  end # initialize

  def send(msg)
    @user_input = msg.chomp
    if @user_input.downcase == "quit"
      self.disconnect()
    else
      begin
        @cmd_count += 1
        @stdin.puts(@user_input)
      rescue Exception => e
        logit("IRBClient: Error writing to @stdin: " + e.to_s)
        reply_user(@jid, "IRBClient: Error writing to @stdin: " + e.to_s, "std")
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
      @stdin.puts("quit")
      sleep 0.2
      reply_user(@jid, "terminating irb thread...", "std")
      Thread.kill(@thread)
      reply_user(@jid, "Disconnected from irb.", "std")
      $bridges.delete($bridged_users[@jid])
      $bridged_users.delete(@jid)
      logit("#{@jid} has disconnected from irb.")
      reply_user(@jid, "Entering lobby...", "std")
      $lobby_users.each do |user|
        reply_user(user, "#{$user_nicks[@jid]} has exited irb and entered the lobby.", "std") unless user == @jid
      end
      $b.add_user_to_lobby(@jid)
      #$b.xmpp.status(nil, $b.get_status)
    rescue Exception => e
      logit("Error (IRBClient::disconnect)" + e.to_s + "\n" + e.to_s)
      reply_user(@jid, "Error (IRBClient::disconnect): " + e.to_s)
    end
  end

  def type
    "irb"
  end

  def info
    "irb:" + @jid
  end

  private

  def send_to_user(msg)
    begin
      reply_user(@jid, msg.chomp, "std") if msg != nil
      #sleep 0.1
    rescue Exception => e
      logit("Error (IRBClient::send_to_user)" + e.to_s)
      reply_user(@jid, "Error (IRBClient::send_to_user): " + e.to_s)
    end  
  end

end

