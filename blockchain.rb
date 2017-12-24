require 'json'
require 'digest/sha2'
require 'securerandom'
require 'sinatra'
require 'sinatra/reloader' # load new code without server restart

class Blockchain
  attr_reader :chain, :current_transactions
  def initialize
    @chain = []
    @current_transactions = []

    new_block(previous_hash: 1, proof: 100)
  end

  def new_block(proof:, previous_hash: nil)
    block = {
      index: @chain.length + 1,
      timestamp: Time.now.to_i,
      transactions: @current_transactions,
      proof: proof,
      previous_hash: previous_hash || hash(@chain.last)
    }

    @current_transactions = []
    @chain << block
    block
  end

  def new_transaction(sender:, recipient:, amount:)
    @current_transactions << {
      sender: sender,
      recipient: recipient,
      amount: amount,
    }
    last_block[:index] + 1
  end

  def last_block
    @chain.last
  end

  def proof_of_work(last_proof)
    proof = 0
    while true
      break if valid_proof?(last_proof, proof)
      proof += 1
    end
    return proof
  end

  def valid_proof?(last_proof, proof)
    guess = (last_proof*proof).to_s
    Digest::SHA256.hexdigest(guess).slice(-4, 4) == "0000"
  end

  def hash(block)
    block_string = Hash[ block.sort ].to_json
    Digest::SHA256.hexdigest(block_string)
  end
end



node_identifier = SecureRandom.uuid().gsub(/-/, '')

blockchain = Blockchain.new

before do
  headers['content-type'] = 'application/json'
end

get '/mine' do
  last_block = blockchain.last_block
  last_proof = last_block[:proof]
  proof = blockchain.proof_of_work(last_proof)

  blockchain.new_transaction(
    sender: "0",
    recipient: node_identifier,
    amount: 1
  )

  previous_hash = blockchain.hash(last_block)
  block = blockchain.new_block(proof: proof, previous_hash: previous_hash)

  resp = {
    message: 'New Block Forged',
    index: block[:index],
    transactions: block[:transactions],
    proof: block[:proof],
    previous_hash: block[:previous_hash]
  }
  resp.to_json
end

post '/transactions/new' do
  params = JSON.parse(request.body.read)

  required = ['sender', 'recipient', 'amount']
  if params.keys.select{|prm| required.include?(prm)}.length != required.length
    response.status = 400
    return 'Missing value'
  end

  index = blockchain.new_transaction(
    sender: params[:sender],
    recipient: params[:recipient],
    amount: params[:amount]
  )
  resp = {message: "Transaction will be added to Block #{index}"}
  response.status = 201
  resp.to_json
end

get '/chain' do
  resp = {
    chain: blockchain.chain,
    length: blockchain.chain.length
  }
  resp.to_json
end
