-- SHOPS
CREATE TABLE shops (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  description TEXT
);

-- USERS
CREATE TABLE users (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(100) NOT NULL UNIQUE,
  password VARCHAR(255) NOT NULL,
  role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'shop_incharge', 'operator')),
  shop_id BIGINT REFERENCES shops(id), -- nullable for admins
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ASSETS
CREATE TABLE assets (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  serial_number VARCHAR(100) UNIQUE NOT NULL,
  shop_id BIGINT NOT NULL REFERENCES shops(id),
  category VARCHAR(50) NOT NULL,
  manufacturer VARCHAR(100),
  purchase_date DATE,
  purchase_cost DECIMAL(10, 2),
  status VARCHAR(20) DEFAULT 'available' CHECK (status IN ('available', 'deployed', 'retired')),
  condition VARCHAR(30) DEFAULT 'good' CHECK (condition IN ('good', 'needs_cleaning', 'damaged')),
  qr_code_url TEXT,
  last_updated_by BIGINT REFERENCES users(id),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ASSET REQUESTS (Shop Incharge -> Admin)
CREATE TABLE asset_requests (
  id BIGSERIAL PRIMARY KEY,
  shop_incharge_id BIGINT NOT NULL REFERENCES users(id),
  request_type VARCHAR(10) NOT NULL CHECK (request_type IN ('add', 'delete')),
  asset_details JSONB, -- for 'add' requests
  asset_id BIGINT REFERENCES assets(id), -- for 'delete' requests
  reason TEXT NOT NULL,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  admin_comments TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  resolved_at TIMESTAMP
);

-- OPERATOR REQUESTS
CREATE TABLE operator_requests (
  id BIGSERIAL PRIMARY KEY,
  operator_id BIGINT NOT NULL REFERENCES users(id),
  shop_incharge_id BIGINT NOT NULL REFERENCES users(id),
  asset_id BIGINT NOT NULL REFERENCES assets(id),
  purpose TEXT NOT NULL,
  duration_days INT NOT NULL,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  shop_incharge_comments TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  resolved_at TIMESTAMP
);

-- CHECKIN/OUT LOGS
CREATE TABLE checkinout_logs (
  id BIGSERIAL PRIMARY KEY,
  operator_id BIGINT NOT NULL REFERENCES users(id),
  asset_id BIGINT NOT NULL REFERENCES assets(id),
  checkout_time TIMESTAMP NOT NULL,
  expected_return_time TIMESTAMP,
  actual_return_time TIMESTAMP,
  condition_at_checkout VARCHAR(30) NOT NULL,
  condition_at_checkin VARCHAR(30),
  checkin_notes TEXT,
  status VARCHAR(20) DEFAULT 'checked_out' CHECK (status IN ('checked_out', 'checked_in')),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
