class CreateAuthorizationCodes < ActiveRecord::Migration[5.2]
  def change
    create_table :authorization_codes do |t|
      t.string :code, null: false, unique: true, index: true
      t.belongs_to :client
      t.string :redirect_url, size: 255
      t.timestamp :expires, null: false
      t.integer :scopes, array: true
      t.integer :redeem_attempts, default: 0
      t.string :code_challenge
      t.string :code_challenge_method, size: 25
      t.timestamps
    end

    create_table :access_tokens_authorization_codes, id: false do |t|
      t.belongs_to :access_token, index: { name: 'idx_token_code_token_id' }
      t.belongs_to :authorization_code, index: { name: 'idx_token_code_auth_cod_id' }
    end

  end
end
