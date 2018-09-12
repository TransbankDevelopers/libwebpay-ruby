require 'signer'
require 'savon'
require_relative 'verifier'
require_relative 'utils'


class WebpayOneClick

  def initialize(configuration)


    @wsdl_path = ''
    @ambient = configuration.environment

    case @ambient
      when 'INTEGRACION'
        @wsdl_path='https://webpay3gint.transbank.cl/webpayserver/wswebpay/OneClickPaymentService?wsdl'
      when 'CERTIFICACION'
        @wsdl_path='https://webpay3gint.transbank.cl/webpayserver/wswebpay/OneClickPaymentService?wsdl'
      when 'PRODUCCION'
        @wsdl_path='https://webpay3g.transbank.cl/webpayserver/wswebpay/OneClickPaymentService?wsdl'
      else
        #Por defecto esta el ambiente de INTEGRACION
        @wsdl_path='https://webpay3gint.transbank.cl/webpayserver/wswebpay/OneClickPaymentService?wsdl'
    end

    @commerce_code = configuration.commerce_code
    @private_key = OpenSSL::PKey::RSA.new(configuration.private_key)
    @public_cert = OpenSSL::X509::Certificate.new(configuration.public_cert)
    @webpay_cert = OpenSSL::X509::Certificate.new(configuration.webpay_cert)
    @client = Savon.client(wsdl: @wsdl_path)

  end


  #######################################################
  def initInscription(username, email, urlReturn)

    initInput ={
        "arg0" => {
              "username" => username,
              "email" => email,
              "responseURL" => urlReturn
        }
    }


    req = @client.build_request(:init_inscription, message: initInput)

    #Firmar documento
    document = sign_xml(req)
    puts document

    begin
      response = @client.call(:init_inscription) do
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
      puts "El Certificado de respuesta es Invalido."
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
        "token" => token.to_s,
        "url" => url.to_s,
        "error_desc" => 'TRX_OK'
    }

    return response_array
  end



  ##############################################
  def finishInscription(token)

    finishInput ={
        "arg0" => {
          "token" => token
        }
    }

    #Preparacion firma
    req = @client.build_request(:finish_inscription, message: finishInput)
    #firmar la peticion
    document = sign_xml(req)

    begin
      puts "Iniciando finishInscription..."
      response = @client.call(:finish_inscription) do
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
      puts "El Certificado de respuesta es Invalido."
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
    authCode 					= response_document.xpath("//authcode").text
    tbkUser 			   	= response_document.xpath("//tbkuser").text
    last4CardDigits		= response_document.xpath("//last4carddigits").text
    creditCardType		= response_document.xpath("//creditcardtype").text


    response_array ={
        "responseCode" 		  => responseCode.to_s,
        "authCode" 					=> authCode.to_s,
        "tbkUser" 				  => tbkUser.to_s,
        "last4CardDigits" 	=> last4CardDigits.to_s,
        "creditCardType" 		=> creditCardType.to_s,
        "error_desc"        => 'TRX_OK'
    }

    return response_array
  end



  ##############################################
  def authorize(buyOrder, tbkUser, username, amount)

    authorizeInput ={
        "arg0" => {
            "buyOrder" => buyOrder,
            "tbkUser" => tbkUser,
            "username" => username,
            "amount" => amount
        }
    }

    #Preparacion firma
    req = @client.build_request(:authorize, message: authorizeInput)
    #firmar la peticion
    document = sign_xml(req)

    #Se realiza el getResult
    begin
      puts "Iniciando authorize..."
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
      puts "El Certificado de respuesta es Invalido."
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
    authCode 					= response_document.xpath("//authorizationcode").text
    transactionId 			   	= response_document.xpath("//transactionid").text
    last4CardDigits		= response_document.xpath("//last4carddigits").text
    creditCardType		= response_document.xpath("//creditcardtype").text


    response_array ={
        "responseCode" 		  => responseCode.to_s,
        "authCode" 					=> authCode.to_s,
        "transactionId" 		=> transactionId.to_s,
        "last4CardDigits" 	=> last4CardDigits.to_s,
        "creditCardType" 		=> creditCardType.to_s,
        "error_desc"        => 'TRX_OK'
    }

    return response_array
  end



  ##############################################
  def reverse(buyOrder)

    reverseInput ={
        "arg0" => {
            "buyorder" => buyOrder
        }
    }

    #Preparacion firma
    req = @client.build_request(:reverse, message: reverseInput)

    #firmar la peticion
    document = sign_xml(req)

    #Se realiza el getResult
    begin
      puts "Iniciando reverse..."
      response = @client.call(:reverse) do
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
      puts 'Respuesta reverse: '+ response.to_s
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
      puts "El Certificado de respuesta es Invalido."
      response_array ={
          "error_desc" => 'El Certificado de respuesta es Invalido'
      }
      return response_array
    else
      puts "El Certificado de respuesta es Valido."
    end


    response_document = Nokogiri::HTML(response.to_s)
    puts response_document.to_s

    response 	= response_document.xpath("//return").text

    response_array ={
        "response"  => response.to_s,
        "error_desc"        => 'TRX_OK'
    }

    return response_array
  end


  ##############################################
  def removeUser(tbkUser, username)

    removeInput ={
        "arg0" => {
            "tbkUser" => tbkUser,
            "username" => username
        }
    }

    #Preparacion firma
    req = @client.build_request(:remove_user, message: removeInput)
    #firmar la peticion
    document = sign_xml(req)
    #document = Util.signXml(req)

    #Se realiza el getResult
    begin
      puts "Iniciando removeUser..."
      response = @client.call(:remove_user) do
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
      puts 'Respuesta remove: '+ response.to_s
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
      puts "El Certificado de respuesta es Invalido."
      response_array ={
          "error_desc" => 'El Certificado de respuesta es Invalido'
      }
      return response_array
    else
      puts "El Certificado de respuesta es Valido."
    end


    response_document = Nokogiri::HTML(response.to_s)
    puts response_document.to_s

    response 	= response_document.xpath("//return").text

    response_array ={
        "response" 		  => response.to_s,
        "error_desc"        => 'TRX_OK'
    }

  return response_array
end


  #######################################################
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