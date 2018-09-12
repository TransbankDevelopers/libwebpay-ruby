require 'signer'
require 'savon'
require_relative 'verifier'
require_relative 'configuration'
require_relative 'webpay'


class Libwebpay

	
  @configuration
  @webpay
  
	
	def getWebpay(config)
      if @webpay == nil
        @webpay = Webpay.new(config)
      end
      return @webpay
    end
	
	def getConfiguration
      if @configuration == nil
        @configuration = Configuration.new
      end
      return @configuration
    end

end
