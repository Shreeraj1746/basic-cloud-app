#!/usr/bin/env python3
import http.server
import socketserver
import os
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('simple-app')

# Get port from environment variable or use default
PORT = int(os.environ.get('PORT', 8080))

class SimpleHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        """Serve a simple text response to any GET request"""
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()

        # Simple HTML response
        html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>AWS CloudFormation Demo App</title>
            <style>
                body {
                    font-family: Arial, sans-serif;
                    margin: 40px;
                    text-align: center;
                }
                .container {
                    max-width: 800px;
                    margin: 0 auto;
                    border: 1px solid #ddd;
                    padding: 20px;
                    border-radius: 5px;
                    background-color: #f9f9f9;
                }
                h1 {
                    color: #2573a7;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>AWS CloudFormation Demo</h1>
                <p>This simple Python application is deployed using AWS CloudFormation.</p>
                <p>The infrastructure includes EC2, ALB, RDS, ElastiCache, and S3 components.</p>
            </div>
        </body>
        </html>
        """

        self.wfile.write(html.encode('utf-8'))
        logger.info(f"Served request from {self.client_address[0]}")

    def log_message(self, format, *args):
        """Override to use our custom logger"""
        logger.info(f"{self.client_address[0]} - {format%args}")

def run_server():
    """Run the HTTP server"""
    logger.info(f"Starting server on port {PORT}")
    with socketserver.TCPServer(("", PORT), SimpleHandler) as httpd:
        logger.info(f"Server running at http://localhost:{PORT}")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            logger.info("Server stopped by user")
        finally:
            httpd.server_close()
            logger.info("Server closed")

if __name__ == "__main__":
    run_server()
