module LtiUtils
  class << self
    def secret
      LTI_CIPHER_SECRET
    end

    def encrypt_json(str)
      CryptoTool.new(secret).encrypt_json(str)
    end

    def decrypt_json(str)
      CryptoTool.new(secret).decrypt_json(str)
    end

    private :secret
  end

  class CryptoTool
    def initialize(secret)
      @secret = secret
    end

    def encrypt_json(plain)
      encrypt(plain.to_json)
    end

    def decrypt_json(cipher)
      return {} if cipher.nil?
      decipher = decrypt(cipher)
      json = JSON.parse(decipher)
      HashHelper.snake_case_symbolize(json)
    rescue StandardError => _e
      {}
    end

    def encrypt(str)
      _encrypt(str, @secret)
    end

    def decrypt(str)
      _decrypt(str, @secret)
    end

    def _encrypt(str, key)
      # OpenSSL::Cipher.ciphers
      cipher = OpenSSL::Cipher.new('AES-192-CBC').encrypt
      cipher.key = Digest::SHA1.hexdigest key
      s = cipher.update(str) + cipher.final
      s = s.unpack('H*')
      s.first # .upcase
    end

    def _decrypt(str, key)
      cipher = OpenSSL::Cipher.new('AES-192-CBC').decrypt
      cipher.key = Digest::SHA1.hexdigest key
      s = [str].pack("H*").unpack("C*").pack("c*")
      cipher.update(s) + cipher.final
    end

    private :_encrypt, :_decrypt
  end
end
