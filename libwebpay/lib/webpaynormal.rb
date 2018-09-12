require 'signer'
require 'savon'
require_relative "verifier"


class WebpayNormal


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
      @client = Savon.client(wsdl: @wsdl_path)

    end


    #######################################################
    def initTransaction(amount, buyOrder, sessionId, urlReturn, urlFinal)


      initInput ={
          "wsInitTransactionInput" => {
              "wSTransactionType" => "TR_NORMAL_WS",
              "buyOrder" => buyOrder,
              "sessionId" => sessionId,
              "returnURL" => urlReturn,
              "finalURL" => urlFinal,
              "transactionDetails" => {
                  "amount" => amount,
                  "commerceCode" => @commerce_code,
                  "buyOrder" => buyOrder
              }
          }
      }

      req = @client.build_request(:init_transaction, message: initInput)

      #Firmar documento
      document = sign_xml(req)
      puts document

      begin
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
      response_document.xpath("//url").each do |url_value|
        url = url_value.text
      end

      puts 'token: '+token
      puts 'url: '+url

      response_array ={
          "token" => token.to_s,
          "url" => url.to_s,
          "error_desc" => "TRX_OK"
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
        puts "Iniciando GetResult..."
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

      accountingdate 		= response_document.xpath("//accountingdate").text
      buyorder 					= response_document.at_xpath("//buyorder").text
      cardnumber 				= response_document.xpath("//cardnumber").text
      amount 						= response_document.xpath("//amount").text
      commercecode 			= response_document.xpath("//commercecode").text
      authorizationcode	= response_document.xpath("//authorizationcode").text
      paymenttypecode 	= response_document.xpath("//paymenttypecode").text
      responsecode 			= response_document.xpath("//responsecode").text
      transactiondate 	= response_document.xpath("//transactiondate").text
      urlredirection 		= response_document.xpath("//urlredirection").text
      vci 							= response_document.xpath("//vci").text

      response_array ={
          "accountingdate" 		=> accountingdate.to_s,
          "buyorder" 					=> buyorder.to_s,
          "cardnumber" 				=> cardnumber.to_s,
          "amount" 						=> amount.to_s,
          "commercecode" 			=> commercecode.to_s,
          "authorizationcode"	=> authorizationcode.to_s,
          "paymenttypecode" 	=> paymenttypecode.to_s,
          "responsecode" 			=> responsecode.to_s,
          "transactiondate" 	=> transactiondate.to_s,
          "urlredirection" 		=> urlredirection.to_s,
          "vci" 							=> vci.to_s,
          "error_desc"        => 'TRX_OK'
      }


      #Realizar el acknowledge
      puts 'Se inicia acknowledgeTransaction...'
      acknowledgeTransaction(token)

      puts 'response normal:...'
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
          "error_desc"  => 'TRX_OK'
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