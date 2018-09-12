require 'signer'
require 'savon'
require_relative "verifier"


class WebpayMallNormal

  def initialize(configuration)

    @wsdl_path = ''
    @ambient = configuration.environment

    case @ambient
      when 'INTEGRACION'
        @wsdl_path='https://webpay3gint.transbank.cl/WSWebpayTransaction/cxf/WSWebpayService?wsdl'
      when 'CERTIFICACION'
        @wsdl_path='https://webpay3gint.transbank.cl/WSWebpayTransaction/cxf/WSWebpayService?wsdl'
      when 'PRODUCCION'
        @wsdl_path='https://webpay3g.transbank.cl/WSWebpayTransaction/cxf/WSWebpayService?wsdl'
      else
        #Por defecto esta el ambiente de INTEGRACION
        @wsdl_path='https://webpay3gint.transbank.cl/WSWebpayTransaction/cxf/WSWebpayService?wsdl'
    end

    @commerce_code = configuration.commerce_code
    @private_key = OpenSSL::PKey::RSA.new(configuration.private_key)
    @public_cert = OpenSSL::X509::Certificate.new(configuration.public_cert)
    @webpay_cert = OpenSSL::X509::Certificate.new(configuration.webpay_cert)
    @store_codes = configuration.store_codes
    @client = Savon.client(wsdl: @wsdl_path)

  end

  #######################################################
  def initTransaction(buyOrder, sessionId, urlReturn, urlFinal, stores)

    detailArray = Array.new

    stores.each do |store|
      wsTransactionDetail = {
          "commerceCode" => store['storeCode'],
          "amount" => store['amount'],
          "buyOrder" => store['buyOrder']
      }
      detailArray.push(wsTransactionDetail)
    end


    inputComplete ={
        "wsInitTransactionInput" => {
            "wSTransactionType" => 'TR_MALL_WS',
            "commerceId" => @commerce_code,
            "sessionId" => sessionId,
            "buyOrder" => buyOrder,
            "returnURL" => urlReturn,
            "finalURL" => urlFinal,
            "transactionDetails" => detailArray
        }
    }

    req = @client.build_request(:init_transaction, message: inputComplete)

    #Firmar documento
    document = sign_xml(req)
    #document = Util.signXml(req)

    puts document

    begin
      puts 'iniciando initMall...'
      response = @client.call(:init_transaction) do
        xml document.to_xml(:save_with => 0)
      end
    rescue Exception, RuntimeError => e
      puts "Ocurrio un error en la llamada a Webpay: "+e.message
      response_array ={
          "error_desc" => "Ocurrio un error en la llamada a Webpay: "+e.message
      }
      return response_array
    end

    token=''
    puts 'response: '+response.to_s

    #Verificacion de certificado respuesta
    tbk_cert = OpenSSL::X509::Certificate.new(@webpay_cert)

    if !Verifier.verify(response, tbk_cert)
      puts "El Certificado de respuesta es Invalido"
      response_array ={
          "error_desc" => 'El Certificado de respuesta es Invalido'
      }
      return response_array
    else
      puts "El Certificado de respuesta es Valido."
    end


    response_document = Nokogiri::HTML(response.to_s)
    response_document.xpath("//token").each do |token_value|
      token = token_value.text
    end
    url=''
    response_document.xpath("//url").each do |url_value|
      url = url_value.text
    end

    puts 'token: '+token
    puts 'url: '+url


    response_array ={
        "token" => token.to_s,
        "url" => url.to_s,
        "error_desc"        => 'TRX_OK'
    }

    return response_array
  end



  ##############################################
  def getTransactionResult(token)

    getResultInput ={
        "tokenInput" => token
    }

    #Preparacion firma
    req = @client.build_request(:get_transaction_result, message: getResultInput)

    #firmar la peticion
    document = sign_xml(req)

    #Se realiza el getResult
    begin
      puts "Iniciando getTransactionResult Mall..."
      response = @client.call(:get_transaction_result) do
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
      puts 'Respuesta getResult: '+ response.to_s
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
          "error_desc" => 'Webservice Webpay responde con null'
      }
      return response_array
    else
      puts "El Certificado de respuesta es Valido."
    end


    token_obtenido=''
    response = Nokogiri::HTML(response.to_s)


    accountingDate 		= response.xpath("//accountingdate").text
    buyOrder 					= response.xpath("//buyorder").text
    cardNumber 				= response.xpath("//cardnumber").text

    #ciclo
    detailOutput     = response.xpath("//detailoutput")

    sessionId 			= response.xpath("//sessionid").text
    transactionDate	= response.xpath("//transactiondate").text
    urlRedirection 	= response.xpath("//urlredirection").text
    vci 			      = response.xpath("//vci").text

    response_array ={
        "accountingDate" 	=> accountingDate.to_s,
        "buyOrder" 				=> buyOrder.to_s,
        "cardNumber" 			=> cardNumber.to_s,
        "detailOutput1" 	=> detailOutput[0].to_s,
        "detailOutput2" 	=> detailOutput[1].to_s,
        "sessionId" 			=> sessionId.to_s,
        "transactionDate" => transactionDate.to_s,
        "urlRedirection" 	=> urlRedirection.to_s,
        "vci" 		        => vci.to_s,
        "error_desc"        => 'TRX_OK'
    }

    puts 'detailOutput: '
    puts detailOutput[0]

    #Realizar el acknowledge
    puts 'Iniciando acknowledge... '
    acknowledgeTransaction(token)

    return response_array
  end



  ################################
  def acknowledgeTransaction(token)
    acknowledgeInput ={
        "tokenInput" => token
    }

    #Preparacion firma
    req = @client.build_request(:acknowledge_transaction, message: acknowledgeInput)

    #Se firma el body de la peticion
    document = sign_xml(req)

    #Se realiza el acknowledge_transaction
    begin
      puts "Iniciando acknowledge_transaction..."
      response = @client.call(:acknowledge_transaction, message: acknowledgeInput) do
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
      puts "El Certificado de respuesta es Invalido."
      response_array ={
          "error_desc" => 'El Certificado de respuesta es Invalido'
      }
      return response_array
    else
      puts "El Certificado de respuesta es Valido."
    end

    response_array ={
        "error_desc" => 'TRX_OK'
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