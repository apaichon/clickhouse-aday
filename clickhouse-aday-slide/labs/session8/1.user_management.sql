-- 1.1 Create and manage users
-- Create a basic user
CREATE USER agent_john 
IDENTIFIED WITH plaintext_password BY 'SecurePass123!'
HOST ANY;

-- Create user with specific host restrictions
CREATE USER underwriter_mary 
IDENTIFIED WITH sha256_password BY 'UW_SecurePass456!'
HOST IP '192.168.1.0/24', '10.0.0.0/8'
SETTINGS readonly = 1;

CREATE USER underwriter_pup
IDENTIFIED WITH plaintext_password BY 'UW_SecurePass456!'
HOST IP '192.168.1.0/24', '10.0.0.0/8'
SETTINGS readonly = 1;

CREATE USER pup_user
IDENTIFIED WITH plaintext_password BY 'P@ssw0rd'
SETTINGS readonly = 1;

-- Create user with password validation
CREATE USER claims_adjuster_bob
IDENTIFIED WITH sha256_password BY 'Claims_Pass789!'
HOST REGEXP '.*\.company\.com'
SETTINGS max_memory_usage = 1000000000; -- 1GB limit


CREATE USER report_viewer
IDENTIFIED WITH plaintext_password BY 'ReadOnly_2024!'
HOST ANY
DEFAULT DATABASE life_insurance
SETTINGS readonly = 2, -- Can change session settings
         max_result_rows = 1000000,
         max_execution_time = 300; -- 5 minutes


Show Tables