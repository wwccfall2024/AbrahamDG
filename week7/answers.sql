-- Create your tables, views, functions and procedures here!
CREATE SCHEMA destruction;
USE destruction;

CREATE TABLE players (
  player_id UNSIGNED PRIMARY KEY NO NULL AUTO_INCREMENT,
  first_name VARCHAR(30) NOT NULL,
  last_name VARCHAR(30) NOT NULL,
  email VARVHAR(50) NOT NULL
);