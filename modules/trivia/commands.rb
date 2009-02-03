# encoding: iso-8859-1
#=======================================================
#  XMPPBridge module commands for trivia 
#
#  Copyright 2009 by Steve Gibson
#  steve@stevegibson.com (xmpp and email)
#
#  This is free software.  You can redistribute it and/or
#  modify it under the terms of the BSD license.  See
#  LICENSE for more details.
#
#=======================================================
# !triv <query>
$cmdarray.push(Botcmd.new(
  :name => 'triv',
  :type => :private,
  :code => %q{
    querystr = "#{arg1} #{arg2} #{arg3}"
    begin
      resultset = $db_trivia.query(querystr)
      resultset.each do |row|
        reply_user(ujid, ">" + row.join(', '),$mtype)
      end
      resultset.close
    rescue SQLite3::Exception #SQLite3::SQLException
      logit("Error (!triv): " + $!)
      reply_user(ujid, "SQLite3: " + $!,$mtype)
    rescue Exception #SQLite3::SQLException
      logit("Error (!triv): " + $!)
      reply_user(ujid, "Error: " + $!,$mtype)
    end
  },
  :return => nil,
  :helptxt => 'Executes SQL statement on trivia database.'
  ))

# !new
$cmdarray.push(Botcmd.new(
  :name => 'new',
  :type => :public,
  :code => %q{
    begin
      player = ujid
      if $bridged_users.include?(player)
        reply_user(player, "You are already bridged.  Use !quit first if you want to join or create a new bridge to another application or game.", $mtype)
      else
        leave_lobby(player, "joining trivia game")
        reply_user(player, "Creating a new trivia game.", $mtype)
        g = TriviaGame.new(
          :playerlimit => 5,
          :startdelay => 10,
          :betweendelay => 10,
          :qcount => 20,
          :qtime => 30
        )
        logit("#{g} created for #{player}.")
        #logit("New Game Object: " + g.to_s)
        g.add_player(player)
        $bridges << g
        $bridged_users[player] = g # add to player=>bridged_app hash
        reply_user(player,"Game #{g.gamenumber} created and joined.", $mtype)
        #$b.xmpp.status(nil, get_status)
        reply_user(player,"There will be a #{g.startdelay} second delay to allow players to join.", $mtype)
        $lobby_users.each do |jid|
          unless jid == player
            reply_user(jid, "#{$user_nicks[ujid]} has created and joined game ##{g.gamenumber}", $mtype)
          end
        end
      end
    rescue Exception => e
      reply_user(ujid, "Error (!new): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => "Create and join a new trivia game."
  ))

# !join [#]
$cmdarray.push(Botcmd.new(
  :name => 'join',
  :type => :public,
  :code => %q{
  begin
    player = ujid
    if $bridged_users.include?(player)
      reply_user(player, "You are already bridged.  Use !quit first if you want to join or create a new bridge to another application or game.", $mtype)
    else
      leave_lobby(player, "joining trivia game")
      if $bridges.length == 0
        reply_user(player, "No games active, starting a new one.", $mtype)
        g = TriviaGame.new(
          :playerlimit => 5,
          :startdelay => 30,
          :betweendelay => 10,
          :qcount => 20,
          :qtime => 30
        )
        logit("#{g} created for #{player}.")
        #logit("New Game Object: " + g.to_s)
        g.add_player(player)
        $bridges << g
        $bridged_users[player] = g # add to player=>bridged_app hash
        reply_user(player,"Game #{g.gamenumber} created and joined.", $mtype)
        #$b.xmpp.status(nil, get_status)
        reply_user(player,"There will be a #{g.startdelay} second delay to allow players to join.", $mtype)
        $lobby_users.each do |jid|
          unless jid == player
            reply_user(jid, "#{$user_nicks[ujid]} has created and joined game ##{g.gamenumber}", $mtype)
          end
        end
      else
        # check existing games to see if we can join
        entered_existing_game = false
        $bridges.each do |game|
          if game.type == "trivia"
            unless game.full?
              if arg1
                next unless arg1 == game.gamenumber.to_s
              end
              game.add_player(player) # add player to the internal player=>score hash
              $bridged_users[player] = game # add to player=>game hash
              game.players.each_key do |p|
                if p == player
                  reply_user(p, "You have joined Game #{game.gamenumber}", $mtype)
                else
                  reply_user(p, ">>> #{$user_nicks[ujid]} has joined the game.", $mtype)
                end
              end
              entered_existing_game = true
              logit("Player: #{player} joined game #{game.gamenumber}")
              $lobby_users.each do |jid|
                unless jid == player
                  reply_user(jid, "#{$user_nicks[ujid]} has joined game #{g.gamenumber}", $mtype)
                end
              end
              break
            end # game.full?
          end # game.type
        end # games.each

        unless entered_existing_game
          if arg1
            reply_user(player, "Game full.", $mtype)
          else
            reply_user(player, "All current games are full... creating a new game.", $mtype)
            g = TriviaGame.new(
              :playerlimit => 5,
              :startdelay => 10,
              :betweendelay => 10,
              :qcount => 20,
              :qtime => 30
            )
            logit("#{g} created for #{player}.")
            #logit("New Game Object: " + g.to_s)
            g.add_player(player)
            $bridges << g
            $bridged_users[player] = g # add to player=>bridged_app hash
          end
        end # unless
        #$b.xmpp.status(nil, $b.get_status)

      end # if games.length
    end # if players.include?
  rescue Exception => e
    logit("Error (!join): " + e.to_s)
    reply_user(ujid, "Error (!join): " + e.to_s, $mtype)
  end
  },
  :return => nil,
  :helptxt => 'Join the specified trivia game (e.g., !join 3)'
  ))

# !trivdebug
$cmdarray.push(Botcmd.new(
  :name => 'trivdebug',
  :type => :private,
  :code => %q{
  begin
    if $trivia_debug
      $trivia_debug = false
      reply_user(ujid, "*trivia_debug OFF.", $mtype)
    else
      $trivia_debug = true
      reply_user(ujid, "*trivia_debug ON.", $mtype)
    end
  rescue Exception => e
    reply_user(ujid, "Error (!trivdebug): " + e.to_s)
  end
  },
  :return => nil,
  :helptxt => 'Toggle trivia debug output to bot masters.'
  ))

