require 'signer'
require 'savon'
require_relative 'verifier'
require_relative 'utils'


class WebpayComplete

  def initialize(configuration)


    @wsdl_path = ''
    @ambient = configuration.environment

    case @ambient
      when 'INTEGRACION'
        @wsdl_path='https://webpay3gint.transbank.cl/WSWebpayTransaction/cxf/WSCompleteWebpayService?wsdl'
      when 'CERTIFICACION'
        @wsdl_path='https://webpay3gint.transbank.cl/WSWebpayTransaction/cxf/WSCompleteWebpayService?wsdl'
      when 'PRODUCCION'
        @wsdl_path='https://webpay3g.transbank.cl/WSWebpayTransaction/cxf/WSCompleteWebpayService?wsdl'
      else
        #Por defecto esta el ambiente de INTEGRACION
        @wsdl_path='https://webpay3gint.transbank.cl/WSWebpayTransaction/cxf/WSCompleteWebpayService?wsd'
    end

    @commerce_code = configuration.commerce_code
    @private_key = OpenSSL::PKey::RSA.new(configuration.private_key)
    @public_cert = OpenSSL::X509::Certificate.new(configuration.public_cert)
    @webpay_cert = OpenSSL::X509::Certificate.new(configuration.webpay_cert)
    @client = Savon.client(wsdl: @wsdl_path)

  end


  #######################################################
  def initComplete(amount, buyOrder, sessionId, cardExpirationDate, cvv, cardNumber)

    inputComplete ={
        "wsCompleteInitTransactionInput" => {
            "transactionType" => 'TR_COMPLETA_WS',
            "sessionId" => sessionId,
            "transactionDetails" => {
                "amount" => amount,
                "buyOrder" => buyOrder,
                "commerceCode" => @commerce_code,
            },
            "cardDetail" => {
                "cardExpirationDate" => cardExpirationDate,
                "cvv" => cvv,
                "cardNumber" => cardNumber
            }
        }
    }

    req = @client.build_request(:init_complete_transaction, message: inputComplete)

    #Firmar documento
    document = sign_xml(req)
    puts document

    begin
      puts "Iniciando initComplete..."
      response = @client.call(:init_complete_transaction) do
        xml document.to_xml(:save_with => 0)
      end
    rescue Exception, RuntimeError => e
      puts "Ocurrio un error en la llamada a Webpay: "+e.message
      response_array ={
          "error_desc" => "Ocurrio un error en la llamada a Webpay: "+e.message
      }
      return response_array
    end

    #Verificacion de certificado respuesta
    tbk_cert = OpenSSL::X509::Certificate.new(@webpay_cert)

    if !Verifier.verify(response, tbk_cert)
      response_array ={
          "error_desc" => 'El Certificado de respuesta es Invalido'
      }
      return response_array
    else
      puts "El Certificado de respuesta es Valido."
    end

    token=''
    response_document = Nokogiri::HTML(response.to_s)
    response_document.xpath("//token").each do |token_value|
      token = token_value.text
    end
    url=''
    response_document.xpath("//urlwebpay").each do |url_value|
      url = url_value.text
    end

    puts 'token: '+token
    puts 'url: '+url

    response_array ={
        "token"      => token.to_s,
        "error_desc" => 'TRX_OK'
    }

    return response_array
  end


  ##############################################
  def queryShare(token, buyOrder, shareNumber)

    inputQuery ={
        "token" => token,
        "buyOrder" => buyOrder,
        "shareNumber" => shareNumber
    }

    #Preparacion firma
    req = @client.build_request(:query_share, message: inputQuery)
    #firmar la peticion
    document = sign_xml(req)
    #document = Util.signXml(req)


    #Se realiza el getResult
    begin
      puts "Iniciando queryShare..."
      response = @client.call(:query_share) do
        xml document.to_xml(:save_with => 0)
      end

    rescue Exception, RuntimeError => e
      puts "Ocurrio un error en la llamada a Webpay: "+e.message
      response_array ={
          "error_desc" => "Ocurrio un error en la llamada a Webpay: "+e.message
      }
      return response_array
    end

    #Se revisa que respuesta no sea nula.
    if response
      puts 'Respuesta finishInscription: '+ response.to_s
    else
      puts 'Webservice Webpay responde con null'
      response_array ={
          "error_desc" => 'Webservice Webpay responde con null'
      }
      return response_array
    end

    puts response

    #Verificacion de certificado respuesta
    tbk_cert = OpenSSL::X509::Certificate.new(@webpay_cert)

    if !Verifier.verify(response, tbk_cert)
      response_array ={
          "error_desc" => 'El Certificado de respuesta es Invalido'
      }
      return response_array
    else
      puts "El Certificado de respuesta es Valido."
    end


    response_document = Nokogiri::HTML(response.to_s)
    puts response_document.to_s

    buyOrder 		  = response_document.xpath("//buyorder").text
    queryId 			= response_document.xpath("//queryid").text
    shareAmount 	= response_document.xpath("//shareamount").text
    token		      = response_document.xpath("//token").text

    response_array ={
        "buyOrder" 		  => buyOrder.to_s,
        "queryId" 			=> queryId.to_s,
        "shareAmount" 	=> shareAmount.to_s,
        "token" 	      => token.to_s,
        "error_desc"    => 'TRX_OK'
    }


    return response_array
  end


  ##############################################
  def authorize(token, buyOrder, gracePeriod, idQueryShare, deferredPeriodIndex)

    input ={
        "token" => token,
        "paymentTypeList" => {
        #    "wsCompletePaymentTypeInput" => {
                "commerceCode" => @commerce_code,
                "buyOrder" => buyOrder,
                "gracePeriod" => gracePeriod,
                "wsCompleteQueryShareInput" => {
                    "idQueryShare" => idQueryShare,
                    "deferredPeriodIndex" => deferredPeriodIndex
                }
          #  }
       }
    }

    #Preparacion firma
    req = @client.build_request(:authorize, message: input)
    #firmar la peticion
    document = sign_xml(req)
    #document = Util.signXml(req)

    #Se realiza el getResult
    begin
      puts "Iniciando authorize..."
      puts document.to_s
      response = @client.call(:authorize) do
        xml document.to_xml(:save_with => 0)
      end

    rescue Exception, RuntimeError => e
      puts "Ocurrio un error en la llamada a Webpay: "+e.message
      response_array ={
          "error_desc" => "Ocurrio un error en la llamada a Webpay: "+e.message
      }
      return response_array
    end

    #Se revisa que respuesta no sea nula.
    if response
      puts 'Respuesta authorize: '+ response.to_s
    else
      puts 'Webservice Webpay responde con null'
      response_array ={
          "error_desc" => 'Webservice Webpay responde con null'
      }
      return response_array
    end

    puts response

    #Verificacion de certificado respuesta
    tbk_cert = OpenSSL::X509::Certificate.new(@webpay_cert)

    if !Verifier.verify(response, tbk_cert)
      response_array ={
          "error_desc" => 'El Certificado de respuesta es Invalido'
      }
      return response_array
    else
      puts "El Certificado de respuesta es Valido."
    end


    response_document = Nokogiri::HTML(response.to_s)
    puts response_document.to_s

    responseCode 		  = response_document.xpath("//responsecode").text
    buyOrder 					= response_document.xpath("//buyorder")
    sharesNumber 			= response_document.xpath("//sharesnumber").text
    amount		        = response_document.xpath("//amount").text
    commerceCode		  = response_document.xpath("//commercecode").text
    authorizationCode = response_document.xpath("//authorizationcode").text
    paymentTypeCode 	= response_document.xpath("//paymenttypecode").text
    sessionId		      = response_document.xpath("//sessionid").text
    transactionDate		= response_document.xpath("//transactiondate").text


    response_array ={
        "responseCode" 		  => responseCode.to_s,
        "buyOrder" 					=> buyOrder.to_s,
        "sharesNumber" 		  => sharesNumber.to_s,
        "amount" 	          => amount.to_s,
        "commerceCode" 		  => commerceCode.to_s,
        "authorizationCode"	=> authorizationCode.to_s,
        "paymentTypeCode" 	=> paymentTypeCode.to_s,
        "sessionId" 	      => sessionId.to_s,
        "transactionDate" 	=> transactionDate.to_s,
        "error_desc"        => 'TRX_OK'
    }

    acknowledgeTransaction(token)

    return response_array
  end


  ################################
  def acknowledgeTransaction(token)
    acknowledgeInput ={
        "tokenInput" => token
    }

    #Preparacion firma
    req = @client.build_request(:acknowledge_complete_transaction, message: acknowledgeInput)

    #Se firma el body de la peticion
    document = sign_xml(req)

    #Se realiza el acknowledge_transaction
    begin
      puts "Iniciando acknowledge_transaction..."
      response = @client.call(:acknowledge_complete_transaction, message: acknowledgeInput) do
        xml document.to_xml(:save_with => 0)
      end

    rescue Exception, RuntimeError => e
      puts "Ocurrio un error en la llamada a Webpay: "+e.message
      response_array ={
          "error_desc" => "Ocurrio un error en la llamada a Webpay: "+e.message
      }
      return response_array
    end

    #Se revisa que respuesta no sea nula.
    if response
      puts 'Respuesta acknowledge_transaction: '+ response.to_s
    else
      puts 'Webservice Webpay responde con null'
      response_array ={
          "error_desc" => 'Webservice Webpay responde con null'
      }
      return response_array
    end

    #Verificacion de certificado respuesta
    tbk_cert = OpenSSL::X509::Certificate.new(@webpay_cert)

    if !Verifier.verify(response, tbk_cert)
      response_array ={
          "error_desc" => 'El Certificado de respuesta es Invalido'
      }
      return response_array
    else
      puts "El Certificado de respuesta es Valido."
    end

    response_array ={
        "error_desc"        => 'TRX_OK'
    }

    return response_array
  end


  def sign_xml (input_xml)

    document = Nokogiri::XML(input_xml.body)
    envelope = document.at_xpath("//env:Envelope")
    envelope.prepend_child("<env:Header><wsse:Security xmlns:wsse='http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd' wsse:mustUnderstand='1'/></env:Header>")
    xml = document.to_s

    signer = Signer.new(xml)

    signer.cert = OpenSSL::X509::Certificate.new(@public_cert)
    signer.private_key = OpenSSL::PKey::RSA.new(@private_key)

    signer.document.xpath("//soapenv:Body", { "soapenv" => "http://schemas.xmlsoap.org/soap/envelope/" }).each do |node|
      signer.digest!(node)
    end

    signer.sign!(:issuer_serial => true)
    signed_xml = signer.to_xml

    document = Nokogiri::XML(signed_xml)
    x509data = document.at_xpath("//*[local-name()='X509Data']")
    new_data = x509data.clone()
    new_data.set_attribute("xmlns:ds", "http://www.w3.org/2000/09/xmldsig#")

    n = Nokogiri::XML::Node.new('wsse:SecurityTokenReference', document)
    n.add_child(new_data)
    x509data.add_next_sibling(n)

    return document
  end



end