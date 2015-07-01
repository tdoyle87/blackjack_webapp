require 'rubygems'
require 'sinatra'

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'your_secret' 
#game constants
  BLACKJACK_AMOUNT = 21
  DEALER_STAYS = 17
  INITIAL_POT = 500

helpers do
  #decides total of cards in the game
  def calculate_total(cards)
    arr = cards.map {|element| element[1]}

    total = 0
    arr.each do |a|
      if a == "A"
        total += 11
      else
        total += a.to_i == 0 ? 10 : a.to_i
      end
    end

    arr.select {|element| element == "A"}.count.times do
      break if total <= BLACKJACK_AMOUNT
      total -= 10
    end
    total
  end
  #sets the suit in the array from a single letter string to a word
  def card_image(card) #['c', '4']
    suit = case card[0]
    when 'H' then 'hearts'
    when 'D' then 'diamonds'
    when 'C' then 'clubs'
    when 'S' then 'spades'
  end
  
  #sets the face cards to words from single letter strings
    value = card[1]
    if ['J', 'Q', 'K', 'A'].include?(value)
      value = case card[1]
      when 'J' then 'jack'
      when 'Q' then 'queen'
      when 'K' then 'king'
      when 'A' then 'ace'
      end
    end
    #using the previous to case statments calls cards image to be used rather then the array
  "<img src='/images/cards/#{suit}_#{value}.jpg' class='card_image'>"
  end
  #if you win it will display this message
  def winner!(msg)
    session[:player_amount] = session[:player_amount] + session[:player_bet]
    @winner = "<strong>#{session[:player_name]} wins! #{session[:player_name]} now has $#{session[:player_amount]}</strong> #{msg}"
    @show_hit_or_stay_buttons = false
    @play_again = true
  end
  #if you lose it will display this message
  def loser!(msg)
    session[:player_amount] = session[:player_amount] - session[:player_bet]
    @loser = "<strong>#{session[:player_name]} loses. #{session[:player_name]} now has $#{session[:player_amount]}</strong> #{msg}"
    @show_hit_or_stay_buttons = false
    @play_again = true
  end
  #if you tie it will display this message
  def tie!(msg)
    session[:player_amount] 
    @winner = "<strong>It's a tie! #{session[:player_name]} now has $#{session[:player_amount]}</strong> #{msg}"
    @show_hit_or_stay_buttons = false
    @play_again = true
  end
end
#ensures that the hit/stay buttons will be available in every url unless turned off.
before do
@show_hit_or_stay_buttons = true
end

#root menu at the start of game decides if there is a player name or not and sends you to the correct url
get '/' do
  if session[:player_name]
    redirect '/game'
  else
    redirect '/new_player'
  end
end
#gets the new player form 
get '/new_player' do
  session[:player_amount] = INITIAL_POT 
  erb :new_player
end
#posts input data from user that was entered in the new_player.erb file
post '/new_player' do
  if params[:player_name].empty?
    @error = "Name is required"
    halt erb :new_player
  end

  session[:player_name] = params[:player_name]
  redirect '/bet'
end
#initiiates the pot to INITIAL_POT amount and directs you to the bet.erb page
get '/bet' do
  if session[:player_amount] == 0
    redirect '/game_over'
  end
  session[:player_bet] = nil
  erb :bet
end
#posts inputed data from the /bet url
post '/bet' do
  if params[:bet_amount].nil? || params[:bet_amount].to_i == 0
    @error = "You have to enter a bet"
    halt erb(:bet)
  elsif params[:bet_amount].to_i > session[:player_amount] 
    @error = "Your bet is more then you have. please choose a number less then #{session[:player_amount]}!"
    halt erb(:bet)
  else
    session[:player_bet] = params[:bet_amount].to_i
    redirect '/game'
  end
end
#builds deck, initiates game, and check for a winning blackjack after initial deal
get '/game' do
  session[:turn] = session[:player_name]
  

  suits = ["H", "D", "S", "C"]
  values = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
  session[:deck] = suits.product(values).shuffle!

  session[:dealer_cards] = []
  session[:player_cards] = []
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  
  dealer_total = calculate_total(session[:dealer_cards])
  player_total = calculate_total(session[:player_cards])
    if player_total == BLACKJACK_AMOUNT
      winner!("#{session[:player_name]} hit blackjack")
    elsif dealer_total == BLACKJACK_AMOUNT
      loser!(" the dealer has blackjack")
    end
  erb :game
end
#deals new card to player if player chooses to hit
post '/game/player/hit' do
  session[:player_cards] << session[:deck].pop
  player_total = calculate_total(session[:player_cards])
   #if player_total == BLACKJACK_AMOUNT
#    winner!("#{session[:player_name]} hit blackjack")
  if player_total > BLACKJACK_AMOUNT
    loser!("#{session[:player_name]} busted at #{player_total}")
  end
  erb :game, layout: false
end
#if player chooses to stay, turns off hit/stay buttons and redirects to dealers turn
post '/game/player/stay' do
  @winner = "You have choosen to stay"
  @show_hit_or_stay_buttons = false
  redirect '/game/dealer'
end 
#starts dealers turn and decides weather dealer will hit or stay/ dealers covered card will now be visible
get '/game/dealer' do 
  session[:turn] = "dealer"
  @show_hit_or_stay_buttons = false
  dealer_total = calculate_total(session[:dealer_cards])
  #if dealer_total == BLACKJACK_AMOUNT
#    loser!(" the dealer has blackjack")
  if dealer_total > BLACKJACK_AMOUNT
    winner!("The dealer busted")
  elsif dealer_total >= DEALER_STAYS
    #dealer stays
    redirect '/game/compare'
  else
    #dealer hits
    @show_dealer_hit_button = true
  end
  erb :game, layout: false
end
#if dealer hits, turns on dealer hit button and issues new card once it has been pressed
post '/game/dealer/hit' do 
  @show_hit_or_stay_buttons = false
  session[:dealer_cards] << session[:deck].pop
  redirect '/game/dealer'
end
#compares cards and decides winner if no one has busted or hit blackjack
get '/game/compare' do
  @show_hit_or_stay_buttons = false
  player_total = calculate_total(session[:player_cards])
  dealer_total = calculate_total(session[:dealer_cards])

  if player_total < dealer_total
    loser!("#{session[:player_name]} stayed at #{player_total}, and the dealer stayed at #{dealer_total}")
  elsif player_total > dealer_total
    winner!("#{session[:player_name]} stayed at #{player_total}, and the dealer stayed at #{dealer_total}")
  else
    tie!("Both #{session[:player_name]} and the dealer stayed at #{player_total}")
  end
  erb :game, layout: false
end
#leaves game with some encouragment and making sure you do not want to play again.
get '/game_over' do
  erb :game_over
end


