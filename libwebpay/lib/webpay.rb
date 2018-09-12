
require_relative 'webpaymallnormal'
require_relative 'webpaynormal'
require_relative 'webpaynullify'
require_relative 'webpaycapture'
require_relative 'webpayoneclick'
require_relative 'webpaycomplete'

class Webpay

  @configuration
  @webpayNormal
  @webpayMallNormal
  @webpayNullify
  @webpayCapture
  @webpayOneClick
  @webpayCompleteTransaction


    # método inicializar clase
    def initialize(params)
      @configuration = params
    end

    def getNormalTransaction
      if @webpayNormal == nil
        @webpayNormal = WebpayNormal.new(@configuration)
      end
      return @webpayNormal
    end

  def getMallNormalTransaction
    if @webpayMallNormal == nil
      @webpayMallNormal = WebpayMallNormal.new(@configuration)
    end
    return @webpayMallNormal
  end

  def getNullifyTransaction
    if @webpayNullify == nil
      @webpayNullify = WebpayNullify.new(@configuration)
    end
    return @webpayNullify
  end

  def getCaptureTransaction
    if @webpayCapture == nil
      @webpayCapture = WebpayCapture.new(@configuration)
    end
    return @webpayCapture
  end

  def getOneClickTransaction
    if @webpayOneClick == nil
      @webpayOneClick = WebpayOneClick.new(@configuration)
    end
    return @webpayOneClick
  end

  def getCompleteTransaction
    if @webpayCompleteTransaction == nil
      @webpayCompleteTransaction = WebpayComplete.new(@configuration)
    end
    return @webpayCompleteTransaction
  end
end



