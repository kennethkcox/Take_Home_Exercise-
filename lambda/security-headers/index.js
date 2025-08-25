'use strict';

exports.handler = (event, context, callback) => {
    // Get the response object from the event
    const response = event.Records[0].cf.response;
    const headers = response.headers;

    // Set a strict Content-Security-Policy header
    // This policy allows scripts and styles from self, and restricts everything else.
    // This is a starting point and would need to be tuned for a real application.
    headers['content-security-policy'] = [{
        key: 'Content-Security-Policy',
        value: "default-src 'self'; img-src 'self' data:; script-src 'self'; style-src 'self' 'unsafe-inline'; object-src 'none';"
    }];

    // Set HTTP Strict Transport Security (HSTS) header
    // This tells browsers to always use HTTPS for this domain.
    headers['strict-transport-security'] = [{
        key: 'Strict-Transport-Security',
        value: 'max-age=63072000; includeSubDomains; preload'
    }];

    // Set X-Content-Type-Options header
    // This prevents browsers from MIME-sniffing a response away from the declared content-type.
    headers['x-content-type-options'] = [{
        key: 'X-Content-Type-Options',
        value: 'nosniff'
    }];

    // Set X-Frame-Options header
    // This provides clickjacking protection.
    headers['x-frame-options'] = [{
        key: 'X-Frame-Options',
        value: 'DENY'
    }];

    // Set X-XSS-Protection header
    // This is a feature of Internet Explorer, Chrome, and Safari that stops pages from loading when they detect reflected cross-site scripting (XSS) attacks.
    headers['x-xss-protection'] = [{
        key: 'X-XSS-Protection',
        value: '1; mode=block'
    }];

    // Return the modified response
    callback(null, response);
};
