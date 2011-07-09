#--
# Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
#
# This file is part of failirc.
#
# failirc is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# failirc is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with failirc. If not, see <http://www.gnu.org/licenses/>.
#++

require 'failirc/common/extensions'

module IRC
  def self.debug (argument, options={})
    return if !ENV['DEBUG'] && !options[:force]

    return if ENV['DEBUG'].to_i < (options[:level] || 1) && !options[:force]

    output = "[#{Time.new}] From: #{caller[0, options[:deep] || 1].join("\n")}\n"

    if argument.is_a?(Exception)
      output << "#{argument.class}: #{argument.message}\n"
      output << argument.backtrace.collect {|stack|
        stack
      }.join("\n")
      output << "\n\n"
    elsif argument.is_a?(String)
      output << "#{argument}\n"
    else
      output << "#{argument.inspect}\n"
    end

    if options[:separator]
      output << options[:separator]
    end

    $stderr.puts output
  end

  module SSLUtils
    def self.self_signed_certificate (bits, comment)
      rsa = OpenSSL::PKey::RSA.new(bits)
    
      cert            = OpenSSL::X509::Certificate.new
      cert.version    = 3
      cert.serial     = 0
      name            = OpenSSL::X509::Name.new
      cert.subject    = name
      cert.issuer     = name
      cert.not_before = Time.now
      cert.not_after  = Time.now + (365*24*60*60)
      cert.public_key = rsa.public_key
    
      ef                    = OpenSSL::X509::ExtensionFactory.new(nil, cert)
      ef.issuer_certificate = cert
    
      cert.extensions = [
        ef.create_extension('basicConstraints', 'CA:FALSE'),
        ef.create_extension('keyUsage', 'keyEncipherment, digitalSignature'),
        ef.create_extension('subjectKeyIdentifier', 'hash'),
        ef.create_extension('extendedKeyUsage', 'serverAuth'),
        ef.create_extension('nsComment', comment),
      ]
    
      aki = ef.create_extension('authorityKeyIdentifier', 'keyid:always,issuer:always')
      cert.add_extension(aki)
      cert.sign(rsa, OpenSSL::Digest::SHA1.new)
    
      return cert, rsa
    end

    def self.context (cert, key)
      context = OpenSSL::SSL::SSLContext.new

      if !cert
        comment   = 'Generated by Ruby/OpenSSL'
        cert, key = self.self_signed_certificate(1024, comment)
      else
        cert = OpenSSL::X509::Certificate.new(cert.is_a?(File) ? cert.read : File.read(cert))
        key  = OpenSSL::PKey::RSA.new(key.is_a?(File) ? key.read : File.read(key))
      end

      context.cert = cert
      context.key  = key

      return context
    end
  end
end