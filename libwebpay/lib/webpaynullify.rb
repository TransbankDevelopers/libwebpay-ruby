require 'signer'
require 'savon'
require_relative "verifier"


class WebpayNullify

    def initialize(configuration)

      @wsdl_path = ''
      @ambient = configuration.environment

      case @ambient
        when 'INTEGRACION'
          @wsdl_path='https://webpay3gint.transbank.cl/WSWebpayTransaction/cxf/WSCommerceIntegrationService?wsdl'
        when 'CERTIFICACION'
          @wsdl_path='https://webpay3gint.transbank.cl/WSWebpayTransaction/cxf/WSCommerceIntegrationService?wsdl'
        when 'PRODUCCION'
          @wsdl_path='https://webpay3g.transbank.cl/WSWebpayTransaction/cxf/WSCommerceIntegrationService?wsdl'
        else
          #Por defecto esta el ambiente de INTEGRACION
          @wsdl_path='https://webpay3gint.transbank.cl/WSWebpayTransaction/cxf/WSCommerceIntegrationService?wsdl'
      end

      @commerce_code = configuration.commerce_code
      @private_key = OpenSSL::PKey::RSA.new(configuration.private_key)
      @public_cert = OpenSSL::X509::Certificate.new(configuration.public_cert)
      @webpay_cert = OpenSSL::X509::Certificate.new(configuration.webpay_cert)
      @client = Savon.client(wsdl: @wsdl_path)

    end


    #######################################################
    def nullify(authorizationCode, authorizedAmount, buyOrder, nullifyAmount, commercecode)


      nullifyInput ={
          "nullificationInput" => {
              "authorizationCode" => authorizationCode,
              "authorizedAmount" => authorizedAmount,
              "buyOrder" => buyOrder,
              "commerceId" => commercecode,
              "nullifyAmount" => nullifyAmount
          }
      }

      req = @client.build_request(:nullify, message: nullifyInput)

      #Firmar documento
      document = sign_xml(req)
      puts document

      begin
        response = @client.call(:nullify) do
          xml document.to_xml(:save_with => 0)
        end
      rescue Exception ,RuntimeError => e
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


      response_document = Nokogiri::HTML(response.to_s)

      authorizationCode = response_document.xpath("//authorizationcode").text
      authorizationDate = response_document.xpath("//authorizationdate").text
      balance 				  = response_document.xpath("//balance").text
      nullifiedAmount 	= response_document.xpath("//nullifiedamount").text
      token 						= response_document.xpath("//token").text

      response_array ={
          "authorizationCode" => authorizationCode.to_s,
          "authorizationDate" => authorizationDate.to_s,
          "balance" 				  => balance.to_s,
          "nullifiedAmount" 	=> nullifiedAmount.to_s,
          "token" 						=> token.to_s,
          "error_desc"        => 'TRX_OK'
      }

      puts 'respuesta: '
      puts response_document

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