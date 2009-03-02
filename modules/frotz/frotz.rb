#=====================================================
# Frotz XMPPBridge module
#
# This module opens a connection to the dfrotz app
# allowing a player on the XMPP Bridge to play one
# of the hosted zgames.
#
# Copyright 2009 by Steve Gibson
# steve@stevegibson.com (xmpp and email)
#
# This is free software.  You can redistribute it and/or
# modify it under the terms of the BSD license.  See
# LICENSE for more details.
# ====================================================


require 'open3'

class FrotzClient

  attr_reader :zgame, :version

  def initialize(ujid, zgame, width)
    @jid = ujid
    @zgame = zgame

    @version = "1.0"

    # check that zgame exists
    unless File.exists?("modules/frotz/zgames/#{zgame}.z5")
      reply_user(@jid, "\"#{zgame}\" is not a valid z-game name. Use !frotzlist to see a list of valid z-games.", "std")
      abort
    else
      @thread = Thread.new do
        begin
          reply_user(@jid, "Connecting to Frotz (#{zgame})...", $mtype)
          reply_user(@jid, "***************************", $mtype)
          reply_user(@jid, "* Frotz Help (!frotzhelp) *", $mtype)
          reply_user(@jid, "*                         *", $mtype)
          reply_user(@jid, "* Sending special chars:  *", $mtype)
          reply_user(@jid, '* \_ = RETURN (by itself) *', $mtype)
          reply_user(@jid, '* \U = undo one turn      *', $mtype)
          reply_user(@jid, "*                         *", $mtype)
          reply_user(@jid, "* Special commands:       *", $mtype)
          reply_user(@jid, "* QUIT = quit the game    *", $mtype)
          reply_user(@jid, "* SAVE = save the game    *", $mtype)
          reply_user(@jid, "* RESTORE = restore saved *", $mtype)
          reply_user(@jid, "*                         *", $mtype)
          reply_user(@jid, "***************************", $mtype)

          logit("#{self} created for #{@jid}.")
          $lobby_users.each do |u|
            reply_user(u, "#{$user_nicks[@jid]} connected to #{zgame}.", $mtype)
          end
          $bridges << self
          $bridged_users[@jid] = self # add to player=>bridged_app hash
          #$b.xmpp.status(nil,$b.get_status)

          @stdin, @stdout, @stderr = Open3.popen3("modules/frotz/dfrotz -Z0 -w #{width} -p modules/frotz/zgames/#{zgame}.z5") 
          return_data = ""
          loop do
            while result = select([@stdout, @stderr], nil, nil, 0.25)
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
          #reply_user(@jid, "frotzclient: " + ex.to_s, "std")
          logit("Error (FrotzClient): #{@jid}: " + ex.to_s)
        end

      end # thread do
      @thread[:name] = "frotz:#{@jid}"
    end # unless zgame
  end # initialize

  def send(msg)
    cmsg = msg.chomp
    if cmsg.downcase == "quit"
      self.disconnect()
    elsif cmsg.downcase == "save"
      reply_user(@jid, "Saving your game under your JID.", "std")
      @stdin.puts("save")
      sleep 0.2
      save_file = @jid.gsub(/\@/,'_')
      @stdin.puts("modules/frotz/zgames/saved/#{save_file}.#{@zgame}")
      reply_user(@jid, "Game saved as '#{save_file}'...", "std")
    elsif cmsg.downcase == "restore"
      reply_user(@jid, "Restoring your saved game...", "std")
      @stdin.puts("restore")
      sleep 0.2
      save_file = @jid.gsub(/\@/,'_')
      reply_user(@jid, "Auto-entering your saved file name: #{save_file}.#{@zgame}", "std")
      @stdin.puts("modules/frotz/zgames/saved/#{save_file}.#{@zgame}")
    else
      begin
        @stdin.puts(cmsg)
      rescue Exception => e
        logit("Error writing to @stdin: " + e.to_s)
        reply_user(@jid, "Error writing to @stdin: " + e.to_s, "std")
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
    begin
      @stdin.puts("quit")
      sleep 0.2
      if @zgame == "hhgg"
        @stdin.puts("\\_")
        sleep 0.2
      end
      @stdin.puts("y")
      sleep 0.2
      reply_user(@jid, "terminating frotz thread...", "std")
      Thread.kill(@thread)
      reply_user(@jid, "Disconnected from Frotz.", "std")
      $bridges.delete($bridged_users[@jid])
      $bridged_users.delete(@jid)
      logit("#{@jid} has disconnected from Frotz:#{@zgame}.")
      reply_user(@jid, "Entering lobby...", "std")
      $lobby_users.each do |user|
        reply_user(user, "#{$user_nicks[@jid]} has exited Frotz and entered the lobby.", "std") unless user == @jid
      end
      $b.add_user_to_lobby(@jid)
      #$b.xmpp.status(nil, $b.get_status)
    rescue Exception => e
      logit("Error (FrotzClient::disconnect)" + e.to_s + "\n" + e.to_s)
      reply_user(@jid, "Error (FrotzClient::disconnect): " + e.to_s)
    end
  end

  def type
    "frotz:#{@zgame}"
  end

  def info
    "frotz:#{@zgame} " + @jid
  end

  private

  def send_to_user(msg)
    begin
      reply_user(@jid, msg.chomp, "std") if msg != nil
      sleep 0.1
    rescue Exception => e
      logit("Error (FrotzClient::send_to_user)" + e.to_s)
      reply_user(@jid, "Error (FrotzClient::send_to_user): " + e.to_s)
    end  
  end

  def abort
    begin
      reply_user(@jid, "Disconnected from Frotz.", "std")
      $bridges.delete($bridged_users[@jid])
      $bridged_users.delete(@jid)
      logit("#{@jid}: aborted Frotz: invalid zgame: #{@zgame}.")
      reply_user(@jid, "Entering lobby...", "std")
      $lobby_users.each do |user|
        reply_user(user, "#{$user_nicks[@jid]} has exited Frotz and entered the lobby.", "std")
      end
      $b.add_user_to_lobby(@jid)
      #$b.xmpp.status(nil, $b.get_status)
    rescue Exception => e
      logit("Error (FrotzClient::abort)" + e.to_s)
      reply_user(@jid, "Error (FrotzClient::abort): " + e.to_s)
    end  
  end
end

