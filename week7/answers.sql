-- Create your tables, views, functions and procedures here!
CREATE SCHEMA destruction;
USE destruction;

CREATE TABLE players (
  player_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  first_name VARCHAR(30) NOT NULL,
  last_name VARCHAR(30) NOT NULL,
  email VARCHAR(50) NOT NULL
);

CREATE TABLE characters(
  character_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  player_id INT UNSIGNED NOT NULL,
  name VARCHAR(30) NOT NULL,
  `level` UNSIGNED TINYINT,
  CONSTRAINT foreign_key_player FOREIGN KEY (player_id) REFERENCES players(player_id)
);

CREATE TABLE winners(
  character_id INT UNSIGNED NOT NULL,
  name VARCHAR(30) NOT NULL,
  CONSTRAINT foreign_key_character FOREIGN KEY (character_id) REFERENCES characters(character_id)
);

CREATE TABLE character_stats(
  character_id INT UNSIGNED NOT NULL,
  health UNSIGNED TINYINT,
  armor UNSIGNED TINYINT,
  CONSTRAINT foreign_key_stats FOREIGN KEY (character_id) REFERENCES character(character_id)
);

CREATE TABLE teams(
  team_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  name VARCHAR(30) NOT NULL
);

CREATE TABLE team_member(
  team_member_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  team_id INT UNSIGNED NOT NULL,
  character_id INT UNSIGNED NOT NULL,
  CONSTRAINT fk_teams FOREIGN KEY (team_id) REFERENCES teams(team_id),
  CONSTRAINT fk_characters FOREIGN KEY (character_id) REFERENCES characters(character_id)
);

CREATE TABLE items(
  item_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  name VARCHAR(30) NOT NULL,
  armor UNSIGNED TINYINT,
  damage UNSIGNED TINYINT
);
CREATE TABLE inventory(
  inventory_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  character_id INT UNSIGNED NOT NULL,
  item_id INT UNSIGNED NOT NULL,
  CONSTRAINT fk_inventory_chcaracters FOREIGN KEY (character_id) REFERENCES characters(character_id),
  CONSTRAINT fk_items FOREIGN KEY (item_id) REFERENCES items(item_id)
);
CREATE TABLE equipped(
  equipped_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  character_id INT UNSIGNED NOT NULL,
  item_id INT UNSIGNED NOT NULL
  CONSTRAINT fk_eqipped_characters FOREIGN KEY (character_id) REFERENCES characters(character_id),
  CONSTRAINT fk_equipped_items FOREIGN KEY (item_id) REFERENCES items(item_id)
);
