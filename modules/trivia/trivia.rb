# encoding: iso-8859-1
#==================================================================
# Trivia XMPPBridge module
#
# This module runs a trivia game and allows multiple players to join
# and compete via the XMPP Bridge.  It uses a sqlite database to
# store trivia question data.
#
#  Copyright 2009 by Steve Gibson
#  steve@stevegibson.com (xmpp and email)
#
#  This is free software.  You can redistribute it and/or
#  modify it under the terms of the BSD license.  See
#  LICENSE for more details.
#
#==================================================================


#==================================================================
# Trivia database creation
#==================================================================
# sql string sanitizer
def sql_sanitize(str)
  SQLite3::Database.quote(str)
end

# Set db_trivia global to access from all threads
$db_trivia = nil

trivia_db = "#{$botname}-trivia.db"
trivia_load_file = "trivia.txt"

# Setup Database for Trivia questions
if File.exists?(trivia_db)
  $db_trivia = SQLite3::Database.new(trivia_db)
else
  $db_trivia = SQLite3::Database.new(trivia_db)
  $db_trivia.execute("CREATE TABLE trivia (number integer, category varchar(25), question varchar(1024), answer varchar(50), regexp varchar(50), author varchar(25), level varchar(10), comment varchar(512), score integer, tip1 varchar(25) ,tip2 varchar(25), tip3 varchar(25))")
  $db_trivia.execute("CREATE INDEX triviaidx ON trivia (question)")
  
  # Insert trivia into trivia table
        ans = ''
        ques = ''
        cat = ''
        regex = ''
        auth = ''
        comment = ''
        level = ''
        score = ''
        tip1 = ''
        tip2 = ''
        tip3 = ''
  qnumber = 0
  IO.foreach(trivia_load_file) do |q|
    begin
      print "."
      if q =~ /^\x0A$/
        if (cat != '') && (ques != '') && (ans != '')
          #print "."
          qnumber += 1
          $db_trivia.execute("INSERT INTO trivia (number,category,question,answer,regexp,author,level,comment,score,tip1,tip2,tip3) VALUES ('#{qnumber.to_s}','" + cat + "','" + sql_sanitize(ques.strip) + "','" + sql_sanitize(ans.strip) + "','" + sql_sanitize(regex) + "','" +  sql_sanitize(auth) + "','" + level + "','" +  sql_sanitize(comment.strip) + "','" + score + "','" + sql_sanitize(tip1) + "','" +  sql_sanitize(tip2) + "','" + sql_sanitize(tip3) + "')")
          ans = ''
          ques = ''
          cat = ''
          regex = ''
          auth = ''
          comment = ''
          level = ''
          score = ''
          tip1 = ''
          tip2 = ''
          tip3 = ''
        else
          next
        end
      elsif q.match(/^Category:(.+)$/)
        cat = $1.strip
        next
      elsif q.match(/^Question:(.+)$/)
        ques = $1.strip
        next
      elsif q.match(/^Answer:(.+)$/)
        ans = $1.strip
      elsif q.match(/^Regexp:(.+)$/)
        regex = $1.strip
        next
      elsif q.match(/^Author:(.+)$/)
        auth = $1.strip
        next
      elsif q.match(/^Comment:(.+)$/)
        comment = $1.strip
        next
      else
        next
      end
    rescue SQLite3::Exception => e
      puts "SQLite3Error (create db_trivia): " + e.to_s
    rescue Exception => ex
      puts "Exception (create db_trivia): " + ex.to_s
    end # begin
  end # foreach
end


#==================================================================
# TriviaGame class
#==================================================================
class TriviaGame

  attr_accessor :version, :qcount, :qtime, :playerlimit, :startdelay, :betweendelay 

  @@total_games = 0

  def initialize(elements)

    @version = "1.0"

    #start_time = DateTime::now
    @@total_games += 1
    @gamenumber = @@total_games
    @started = false
    @between_questions = false
    @full = false
    @qtimer = 0
    @current_qnum = 0
    @starttime = DateTime::now
    @answer = ""
    @regex = ""
    @players = Hash.new(0)

    @elements = elements
    @qcount = @elements[:qcount]
    @qtime = @elements[:qtime]
    @playerlimit = @elements[:playerlimit]
    @startdelay = @elements[:startdelay]
    @betweendelay = @elements[:betweendelay]

    
    @game_thread = Thread.new do
      trivia_counter = 0
      loop do
        sleep 0.1
        # gameloop counter - when it reaches 10 (1 second) then
        # run the gameloop() method to update the timers and expire
        # questions or games
        trivia_counter += 1
        if trivia_counter == 10
          #run gameloop()
          begin
            gameloop()
          rescue Exception => e
            logit("Error (trivia gameloop()): " + e.to_s)
          ensure
            trivia_counter = 0
          end
        end
      end
    end
    @game_thread[:name] = "trivia:#{@gamenumber}"

  end

  def type
    "trivia game #{@gamenumber}"
  end

  def timer
    @qtimer
  end

  def timer_reset
    @qtimer = 0
  end

  def timer_incr
    @qtimer += 1
  end

  def current_qnum
    @current_qnum
  end

  def current_qnum_incr
    @current_qnum += 1
  end

  def current_qnum_reset
    @current_qnum = 0
  end

  def answer=(ans)
    @answer = ans
  end

  def answer
    @answer
  end

  def regex=(re)
    @regex = re
  end

  def regex
    @regex
  end

  def totalgames
    @@total_games
  end

  def full?
    @full
  end

  def started=(started)
    @started = started
  end

  def started?
    @started
  end

  def between_questions?
    @between_questions
  end

  def between_questions=(tf)
    @between_questions = tf
  end

  def gamenumber
    @gamenumber
  end

  def starttime
    @starttime
  end

  def players
    @players
  end

  def playerscore_incr(jid_rsrc)
    @players[jid_rsrc] += 1
  end

  def add_player(jid_rsrc)
    @players[jid_rsrc] = 0
    if @players.length == @playerlimit
      @full = true
    end
  end

  def remove_player(jid_rsrc)
    @players.delete(jid_rsrc)
    if @players.length < @playerlimit
      @full = false
    end
  end

  def disconnect(ujid)
    remove_player(ujid)
    $bridged_users.delete(ujid)
    logit("#{ujid} has quit Trivia game #{@gamenumber}.")
    if @players.length == 0
      $bridges.delete(self)
      Thread.kill(@game_thread)
    else
      @players.each_key do |p|
        unless p == ujid
          reply_user(p, "<<< #{$user_nicks[ujid]} has quit the game.", $mtype)
        end
      end
    end
  end

  def enumerate
    "game: #{@gamenumber}, player_count: #{@players.length}, started: #{@started}, qcount: #{@qcount}, current_qnum: #{@current_qnum}, btwq: #{@between_questions}, timer: #{@qtimer}" 
  end

  #==================================================================
  # Process Message 
  #
  def process_msg(ujid, timestr, msg)
    # set message reply type to standard Jabber message
    $mtype = "std"
    game = self
    player = ujid
    #
    # relay msg to all other players
    game.players.each_key do |p|
      unless player == p
        reply_user(p,"<#{$user_nicks[player]}> " + msg.strip, $mtype)
      end
    end
    
    # check msg against correct answer
    if game.started? and not game.between_questions?
      answer = msg.strip.downcase
      g_answer = game.answer.strip.downcase
      g_regex = game.regex.strip
      notify("caught answer: #{answer}, player_nick: #{$user_nicks[player]}, g_regex: #{g_regex}, g_answer: #{g_answer}") if $trivia_debug
      if answer.match(/#{g_regex}/i)
        game.playerscore_incr(player)
        game.players.each_key do |p|
          reply_user(p, "#{$user_nicks[player]} got the CORRECT ANSWER!!!", $mtype)
          sleep 0.1
          reply_user(p, "Answer: #{game.answer}", $mtype)
          sleep 0.1
          if player == p
            reply_user(p, "Way to go #{$user_nicks[p]}!", $mtype)
          else
            reply_user(p, "Better luck on the next question...", $mtype)
          end
        end
        if game.current_qnum == game.qcount
          endgame()
        else
          game.between_questions=(true)
          game.timer_reset
        end
      end
    end
    return "handled"
  end

  #==================================================================
  #  End Game 
  #
  def endgame
    $mtype = "std"
    game = self
    game.players.each_key do |player|
      reply_user(player,".", $mtype)
      sleep 0.1
      reply_user(player,"=== GAME OVER ===", $mtype)
      sleep 0.1
      game.players.each do |p,score|
        reply_user(player,"#{$user_nicks[p]}  score: #{score}", $mtype)
        sleep 0.1
      end
      
      logit("Game #{game.gamenumber} Completed.")
      $bridged_users.delete(player)
      $lobby_users.each do |user|
        reply_user(user, "#{$user_nicks[player]} has entered the lobby.", $mtype) unless user == player
      end
      $b.add_user_to_lobby(player)
      reply_user(player,"Entering lobby...", $mtype)
    end
    #$b.xmpp.status(nil, $b.get_status)
    if $bridges.include?(game)
      $bridges.delete(game)
    end
    @game_thread.exit
  end

  private

  #==================================================================
  #   Get Trivia Question
  #
  def get_question
    begin
      retarray = Array.new
      resultset = $db_trivia.query("SELECT number,category,question,answer,regexp FROM trivia ORDER BY random() LIMIT 1")
      resultset.each do |row|
        retarray = [row[0], row[1], row[2], row[3], row[4]]
      end
      retarray
    rescue SQLite3::Exception => e
      logit("Error (get_question): " + e.to_s)
      notify("Error (get_question): " + e.to_s)
    rescue Exception => ex
      logit("Error (get_question): " + ex.to_s)
      notify("Error (get_question): " + ex.to_s)
    end
  end

  #==================================================================
  #   Gameloop
  #
  def gameloop
    $mtype = "std"
    game = self
    game.timer_incr
    if game.started?
      #logit(game.to_s)
      #notify(game.to_s)
      if game.between_questions? or game.current_qnum == 0
        if game.timer == game.betweendelay or game.current_qnum == 0
          game.timer_reset
          game.between_questions=(false)
          game.current_qnum_incr
          qnum, category, question, answer, regexp = get_question()
          game.answer=(answer)
          game.regex=(regexp)
          notify("g: #{game.gamenumber}, qnum: #{qnum}, c: #{category}, q: #{question}, a: #{answer}, re:#{regexp}") if $trivia_debug
          game.players.each_key do |player|
            reply_user(player, ".", $mtype)
            sleep 0.05
            reply_user(player, "=== Question #{game.current_qnum} of #{game.qcount} ===", $mtype)
            sleep 0.05
            reply_user(player, "Category: " + category, $mtype)
            sleep 0.05
            reply_user(player, "Question [#{qnum}]: " + question, $mtype)
          end
        elsif game.betweendelay - game.timer == 5
          game.players.each_key do |player|
            sleep 0.05
            reply_user(player, "Get ready... next question coming!", 
$mtype)
          end
        end
      else

        # check if the question timer has expired 
        if game.timer == game.qtime
          game.timer_reset
          game.between_questions=(true)
          game.players.each_key do |player|
            reply_user(player, "Time's up!", $mtype)
            sleep 0.05
            reply_user(player, "Answer: " + game.answer, $mtype)
            sleep 0.05
          end
          if game.current_qnum == game.qcount
            endgame()
          end
        end

        # give a warning if time is running out
        if game.qtime - game.timer == 6
          game.players.each_key do |player|
            reply_user(player, "5 seconds...", $mtype)
            sleep 0.05
          end
        #elsif game.qtime - game.timer == 5
        #  game.players.each_key do |player|
        #    reply_user(player, "4...", $mtype)
        #    sleep 0.05
        #  end
        #elsif game.qtime - game.timer == 4
        #  game.players.each_key do |player|
        #    reply_user(player, "3...", $mtype)
        #    sleep 0.05
        #  end
        #elsif game.qtime - game.timer == 3
        #  game.players.each_key do |player|
        #    reply_user(player, "2...", $mtype)
        #    sleep 0.05
        #  end
        #elsif game.qtime - game.timer == 2
        #  game.players.each_key do |player|
        #    reply_user(player, "1...", $mtype)
        #    sleep 0.05
        #  end
        end

      end
    else
      if game.timer == game.startdelay
        game.started=(true)
        logit("Game #{game.gamenumber} Started.")
      end
      if game.startdelay - game.timer == 10
        game.players.each_key do |player|
          reply_user(player, "Game starting in 10 seconds...", $mtype)
          sleep 0.1
        end
      end
    end # game.started?
  end
end
