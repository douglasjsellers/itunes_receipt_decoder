##
# ItunesReceiptDecoder
module ItunesReceiptDecoder
  ##
  # ItunesReceiptDecoder::Decode
  class Decode
    RECEIPT_FIELDS = {
      0 => :environment,
      2 => :bundle_id,
      3 => :application_version,
      12 => :creation_date,
      17 => :in_app,
      19 => :original_application_version,
      21 => :expiration_date,
      1701 => :quantity,
      1702 => :product_id,
      1703 => :transaction_id,
      1705 => :original_transaction_id,
      1704 => :purchase_date,
      1706 => :original_purchase_date,
      1708 => :expires_date,
      1712 => :cancellation_date,
      1711 => :web_order_line_item_id
    }

    attr_accessor :receipt_data
    attr_accessor :receipt

    def initialize(receipt_data)
      @receipt_data = Base64.strict_decode64(receipt_data)
      @receipt = {}
    end

    def decode
      self.receipt = parse_app_receipt_fields(payload.value)
    end

    private

    def parse_app_receipt_fields(fields)
      result = {}
      fields.each do |seq|
        type, _version, value = seq.value.map(&:value)
        next unless (field = RECEIPT_FIELDS[type.to_i])
        build_result(result, field, value)
      end
      result
    end

    def build_result(result, field, value)
      value = OpenSSL::ASN1.decode(value).value
      case field
      when :in_app
        (result[field] ||= []).push(parse_app_receipt_fields(value))
      when :creation_date, :expiration_date, :purchase_date,
           :original_purchase_date, :expires_date, :cancellation_date
        result[field] = value.empty? ? nil : Time.parse(value).utc
      else
        result[field] = value.class == OpenSSL::BN ? value.to_i : value.to_s
      end
    end

    def payload
      @payload ||= OpenSSL::ASN1.decode(pkcs7.data)
    end

    def pkcs7
      return @pkcs7 if @pkcs7
      @pkcs7 = OpenSSL::PKCS7.new(receipt_data)
      @pkcs7.verify(nil, Config.certificate_store, nil, nil)
      @pkcs7
    end
  end
end
