/**
 * CloudFront Function for Multi-Domain URL Rewriting
 *
 * This function rewrites incoming requests to map domain names to their
 * corresponding S3 bucket paths for multi-domain hosting.
 *
 * Examples:
 * - domain1.com/ -> /domain1.com/index.html
 * - domain2.com/about.html -> /domain2.com/about.html
 * - domain3.com/assets/logo.png -> /domain3.com/assets/logo.png
 */

function handler(event) {
    var request = event.request;
    var host = request.headers.host.value;
    var uri = request.uri;

    // Skip rewriting if using CloudFront default domain (*.cloudfront.net)
    // In this case, paths are already prefixed with domain folders
    if (host.endsWith('.cloudfront.net')) {
        // Just add index.html for directory paths
        if (uri === '/' || uri === '') {
            request.uri = '/index.html';
        } else if (uri.endsWith('/')) {
            request.uri = uri + 'index.html';
        } else if (!uri.includes('.') && !uri.endsWith('/')) {
            // Path without extension, check if it needs index.html
            request.uri = uri + '/index.html';
        }
        return request;
    }

    // For custom domains, rewrite to prepend domain folder
    // Remove trailing slash for non-root paths
    if (uri.length > 1 && uri.endsWith('/')) {
        uri = uri.slice(0, -1);
    }

    // If URI is root or doesn't have an extension, append index.html
    if (uri === '' || uri === '/' || !uri.includes('.')) {
        if (uri === '' || uri === '/') {
            uri = '/index.html';
        } else {
            // For directory-like paths without extension
            uri = uri + '/index.html';
        }
    }

    // Prepend the domain name to the URI for S3 path routing
    // This maps: domain.com/page.html -> /domain.com/page.html in S3
    var newUri = '/' + host + uri;

    // Update the request URI
    request.uri = newUri;

    return request;
}
