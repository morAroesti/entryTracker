import os
import socket
import datetime
import pymysql
from flask import Flask, jsonify

app = Flask(__name__)

# Database connection configurations (update with your MySQL RDS or Docker MySQL config)
DB_CONFIG = {
    'host': os.environ.get('DB_HOST', 'mysql'),  # Use 'mysql' for Docker service name or your RDS endpoint for AWS
    'user': os.environ.get('DB_USER', 'root'),  # MySQL user
    'password': os.environ.get('DB_PASSWORD', 'password'),  # MySQL password
    'database': os.environ.get('DB_NAME', 'app_db')  # Database name
}

def get_db_connection():
    connection = pymysql.connect(**DB_CONFIG)
    return connection

def create_table_if_not_exists():
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS request_log (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    hostname VARCHAR(255),
                    ip_address VARCHAR(255),
                    timestamp DATETIME
                );
            """)
        connection.commit()
    finally:
        connection.close()

@app.route('/')
def home():
    hostname = socket.gethostname()
    ip_address = socket.gethostbyname(hostname)
    timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')

    current_entry = {
        "hostname": hostname,
        "ip_address": ip_address,
        "timestamp": timestamp
    }

    # Connect to the database
    try:
        connection = get_db_connection()
        create_table_if_not_exists()

        # Insert the current entry into the database
        with connection.cursor() as cursor:
            cursor.execute("""
                INSERT INTO request_log (hostname, ip_address, timestamp)
                VALUES (%s, %s, %s)
            """, (hostname, ip_address, timestamp))
        connection.commit()

        # Fetch all entries from the database
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT hostname, ip_address, timestamp
                FROM request_log
                ORDER BY timestamp DESC
            """)
            entries = cursor.fetchall()

        previous_entries = [
            {"hostname": row[0], "ip_address": row[1], "timestamp": row[2].strftime('%Y-%m-%d %H:%M:%S')}
            for row in entries
        ]

        connection.close()

        return jsonify({
            "message": "Data fetched successfully from the database.",
            "current_entry": current_entry,
            "previous_entries": previous_entries
        })
    
    except Exception as e:
        return jsonify({
            "message": f"No connection to the database. Showing current entry only. Error: {str(e)}",
            "current_entry": current_entry
        })

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
