/* certwatch_db - Database schema
 * Written by Rob Stradling
 * Copyright (C) 2015-2016 COMODO CA Limited
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

CREATE OR REPLACE FUNCTION download_cert(
	cert_identifier			text
) RETURNS text
AS $$
DECLARE
	t_b64Certificate	text;
	t_output			text;
BEGIN
	IF length(cert_identifier) = 64 THEN
		SELECT replace(encode(c.CERTIFICATE, 'base64'), chr(10), '')
			INTO t_b64Certificate
			FROM certificate c
			WHERE digest(c.CERTIFICATE, 'sha256') = decode(cert_identifier, 'hex');
	ELSE
		SELECT replace(encode(c.CERTIFICATE, 'base64'), chr(10), '')
			INTO t_b64Certificate
			FROM certificate c
			WHERE c.ID = cert_identifier::bigint;
	END IF;
	IF t_b64Certificate IS NULL THEN
		RETURN NULL;
	END IF;

	t_output :=
'[BEGIN_HEADERS]
Content-Disposition: attachment; filename="' || cert_identifier || '.crt"
Content-Type: application/pkix-cert
[END_HEADERS]
';

	t_output := t_output || '-----BEGIN CERTIFICATE-----' || chr(10);

	WHILE length(t_b64Certificate) > 64 LOOP
		t_output := t_output || substring(
			t_b64Certificate from 1 for 64
		) || chr(10);
		t_b64Certificate := substring(t_b64Certificate from 65);
	END LOOP;
	IF coalesce(t_b64Certificate, '') != '' THEN
		t_output := t_output || t_b64Certificate || chr(10);
	END IF;

	t_output := t_output || '-----END CERTIFICATE-----' || chr(10);

	RETURN t_output;
END;
$$ LANGUAGE plpgsql;
