# failirc, a fail IRC library.
#
# Copyleft meh. [http://meh.doesntexist.org | meh.ffff@gmail.com]
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

require 'openssl'

module IRC

module SSLUtils
    def self.selfSignedCertificate (bits, comment)
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
  
        return [cert, rsa]
    end

    def self.context (cert, key)
        context = OpenSSL::SSL::SSLContext.new

        if !cert
            comment   = 'Generated by Ruby/OpenSSL'
            cert, key = self.selfSignedCertificate(1024, comment)
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
