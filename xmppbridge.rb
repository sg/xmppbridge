#!/usr/bin/env ruby
# encoding: iso-8859-1
##!/opt/ruby1.9/bin/ruby1.9.1
#
# XMPP Bridge
# Copyright 2009 by Steve Gibson
# steve@stevegibson.com (xmpp and email)
#
# This is free software.  You can redistribute it and/or
# modify it under the terms of the BSD license.  See
# LICENSE for more details.
#

require 'xmpp4r-simple'
require 'xmpp4r/version/helper/simpleresponder'
require 'sqlite3'
require 'botcmd'

$version = "1.0.2"
$product = "XMPP Bridge"
$uname = `uname -s -r`
$uname.chomp!

#==================================================================
# Bot config
#==================================================================
unless ARGV[0]
  $botname = "bridge"
else
  $botname = ARGV[0]
end

cfgfile = "#{$botname}.conf"

unless File.exists?(cfgfile)
  puts "can't find #{$botname}.conf -- exiting..."
  exit 1
end

config = Hash.new
IO.foreach(cfgfile) do |line|
  if line =~ /^#/
    next
  elsif line =~ /^\s*$/
    next
  else
    tag,value = line.split(':',2)
    config[tag] = value.strip
  end
end

$botjid = config['botjid'] + "/#{$version}"
botpasswd = config['botpasswd']
$botnick = config['botnick']
$default_master = config['default_master']
database = config['database']
if config['accept_subs'] == "true"
  accept_subs = true
else
  accept_subs = false
end

# Debuging: true = extensive xmpp output to stderr
debug_mode = true

# Initial setting for botmasters to see source code for botcmds when
# they are executed (very noisy when enabled)
$show_code = false

# ThreadGroups
$tg_main = ThreadGroup.new
$tg_msg = ThreadGroup.new
$tg_con = ThreadGroup.new

# Assign current thread to a variable
$mainthread = Thread.current
$mainthread[:name] = "main"
$tg_main.add($mainthread)


#==================================================================
# Counters and Logs
#==================================================================

# Message counters 
$total_msg_received = 0
$total_msg_sent = 0

# Setup log file
$logfile = File.new("#{$botname}.log", "w+")
$logfile.write("\n" + Time.now.strftime('%Y-%m-%d %H:%M:%S') + " == #{$botname} startup\n")


#==================================================================
# Create some Hashes and Arrays
#==================================================================
# Array of Botcmd objects
# see botcmd.rb for Class definition
$cmdarray = Array.new

# Create an array to hold the list of module names
$modules = Array.new
$modules = config['modules'].split(',')

# Create an array of bot masters.  This array gets populated from
# the database on startup to make querying whether or not someone is
# a bot master a bit easier.
$masters = Array.new

# Create a hash of player jids => nicks
$user_nicks = Hash.new

# Create a bridged_app objects array
$bridges = Array.new

# Create a hash of player jids => bridged_app objects
$bridged_users = Hash.new

# Create an array of Lobby users
$lobby_users = Array.new

# Create an array of jids who have sent messages (commands) to the bot
$messagers = Array.new

# Create an array for storing the last X messages sent to the lobby
$lobby_msg_history = Array.new

# Greetings (not used yet)
$greetings = Array.new
$greetings[0,4] = ["Hi","Hey","Hello","Greetings","Welcome"]

# Acknowledgement messages (not used yet)
$acknowledgements = Array.new
$acknowledgements[0,4] = ["ok","will do","roger that","consider it done","as you wish"]

# Confirmation messages (not used yet)
$confirmations = Array.new
$confirmations[0,2] = ["done","task completed","finished"]

# Hash of users and warning levels   jid => warn_level
# (not currently implemented)
$warning = Hash.new

# Hash of banned JIDs   jid => reason
$banned_users = Hash.new


#==================================================================
# "Global" Methods
#==================================================================

def logit(msg)
  $logfile.write(Time.now.strftime('%Y-%m-%d %H:%M:%S') + " == #{msg}\n")
  $logfile.flush
end

# reply_user function - sends a msg back to the user using the specified
# format (std=standard jabber msg, pub=say in muc, priv=private muc msg).
def reply_user(user, msg, type)
  begin
    #logit("msg type=#{type}")
    $total_msg_sent += 1
    if type == nil
      type = "std"
    end
    if type == "std"
      $b.xmpp.deliver(user, msg)
    else
      # muc message types are not currently handled here...
      # they are handled by the mucbot module.
    end
  rescue Exception => e
    logit("Error (reply_user): " + e.to_s)
  end
end

def sql_sanitize(str)
  SQLite3::Database.quote(str)
end

#==================================================================
# Open/Create Sqlite3 databases
#==================================================================
if File.exists?(database)
  # database exists; open and read data into run-time arrays
  $db = SQLite3::Database.new(database)

  # load bot masters
  resultset = $db.query("SELECT rjid FROM roster WHERE rlvl='admin' OR rlvl='owner'")
  unless resultset == nil
    resultset.each {|row|
      logit("loaded bot master: " + row[0].to_s)
      $masters << row[0].strip
    }
  end
  resultset.close

  # load bans
  resultset = $db.query("SELECT jid,reason FROM bans")
  unless resultset == nil
    resultset.each {|row|
      $banned_users[row[0]] = row[1]
      logit("loaded banned jid: " + row[0].to_s)
    }
  end
  resultset.close

else # database doesn't exist; create and populate
  $db = SQLite3::Database.new(database)

  # create tables & indexes
  $db.execute("CREATE TABLE roster (rjid varchar(50), rlvl varchar(5), rnick varchar(25), rpasswd varchar(50), lastseen varchar(25), lastpres varchar(12), in_lobby integer)")
  $db.execute("CREATE INDEX rosteridx ON roster (rjid)")
  $db.execute("CREATE TABLE info (category varchar(20), data varchar(512))")
  $db.execute("CREATE INDEX infoidx ON info (data)")
  $db.execute("CREATE TABLE cmdhist (time varchar(20), jid varchar(50), cmd varchar(1024))")
  $db.execute("CREATE INDEX cmdhistidx ON cmdhist (time)")
  $db.execute("CREATE TABLE bans (jid varchar(50), reason varchar(256))")
  $db.execute("CREATE INDEX banidx ON bans (jid)")

  # populate roster table with default bot masters
  $db.execute("INSERT INTO roster (rjid,rlvl,rnick,rpasswd,in_lobby) VALUES ('#{$default_master}','owner','Steve','foobar99', '1')")
  $db.execute("INSERT INTO roster (rjid,rlvl,rnick,rpasswd,in_lobby) VALUES ('steve@xmpplink.com','owner','SteveX','foobar99', '1')")
  $masters << $default_master
  logit("done inserting default master user")

  # insert quotes into info table
  #quotefile = "quotes.txt"
  #IO.foreach(quotefile) do |q|
  #  print "."
  #  $db.execute("INSERT INTO info (category,data) VALUES ('quote','" + sql_sanitize(q.strip) + "')")
  #end

  # insert links into info table
  linkfile = "links.txt"
  IO.foreach(linkfile) do |link|
    print "."
    $db.execute("INSERT INTO info (category,data) VALUES ('link','" + sql_sanitize(link.strip) + "')")
  end

  logit("done inserting info records")
  #
  resultset = $db.query("SELECT COUNT(*) FROM info")
  resultset.each { |r|
    logit("record count = #{r}")
  }
  resultset.close
end


#==================================================================
# Load Modules
#==================================================================
$modules.each do |m|
  load "modules/#{m}/#{m}.rb"
  load "modules/#{m}/commands.rb"
end


#==================================================================
# Start the bot
#==================================================================

$b = XMPPBridgeMain.new(database, botpasswd, accept_subs, debug_mode)

# Stop the mainthread and wait for wakeup
Thread.stop

# On Thread.wakeup, kill the bot
begin
  # kill the bot
  $b.xmpp.disconnect
rescue Exception => e
  logit("Error (disconnect): " + e.to_s)
  reply_user($ujid, "Error (disconnect): " + e.to_s, $mtype)
  exit
end
 
