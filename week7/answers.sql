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
  `level` TINYINT UNSIGNED,
  CONSTRAINT fk_characters_player FOREIGN KEY (player_id) REFERENCES players(player_id)
);

CREATE TABLE winners(
  character_id INT UNSIGNED NOT NULL,
  name VARCHAR(30) NOT NULL,
  CONSTRAINT fk_winners_character FOREIGN KEY (character_id) REFERENCES characters(character_id)
);

CREATE TABLE character_stats(
  character_id INT UNSIGNED NOT NULL,
  health TINYINT UNSIGNED,
  armor TINYINT UNSIGNED,
  CONSTRAINT fk_character_stats_stats FOREIGN KEY (character_id) REFERENCES characters(character_id)
);

CREATE TABLE teams(
  team_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  name VARCHAR(30) NOT NULL
);

CREATE TABLE team_members(
  team_member_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  team_id INT UNSIGNED NOT NULL,
  character_id INT UNSIGNED NOT NULL,
  CONSTRAINT fk_team_member_teams FOREIGN KEY (team_id) REFERENCES teams(team_id),
  CONSTRAINT fk_team_member_characters FOREIGN KEY (character_id) REFERENCES characters(character_id)
);

CREATE TABLE items(
  item_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  name VARCHAR(30) NOT NULL,
  armor TINYINT UNSIGNED,
  damage TINYINT
);
CREATE TABLE inventory(
  inventory_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  character_id INT UNSIGNED NOT NULL,
  item_id INT UNSIGNED NOT NULL,
  CONSTRAINT fk_inventory_characters FOREIGN KEY (character_id) REFERENCES characters(character_id),
  CONSTRAINT fk_inventory_items FOREIGN KEY (item_id) REFERENCES items(item_id)
);
CREATE TABLE equipped(
  equipped_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  character_id INT UNSIGNED NOT NULL,
  item_id INT UNSIGNED NOT NULL,
  CONSTRAINT fk_equipped_characters FOREIGN KEY (character_id) REFERENCES characters(character_id),
  CONSTRAINT fk_equipped_items FOREIGN KEY (item_id) REFERENCES items(item_id)
);
-- Views -- 
CREATE VIEW character_items AS 
SELECT i.item_id,i.name
FROM items i
  JOIN(
    SELECT item_id, character_id
      FROM inventory

    UNION 

    SELECT item_id, character_id
    FROM equipped
  ) AS total_items ON i.item_id = total_items.item_id
GROUP BY i.item_id, i.name;

-- Team items --
CREATE VIEW team_items AS
SELECT i.item_id, i.name
FROM items i
JOIN (
  SELECT item_id
  FROM inventory inv
  WHERE inv.character_id IN (
        SELECT character_id
        FROM team_members
    )

  UNION 

  SELECT item_id
  FROM equipped eq
  WHERE eq.character_id IN (
        SELECT character_id
        FROM team_members
    )
) AS combined_player_items ON i.item_id = combined_player_items.item_id
GROUP BY i.item_id, i.name;


-- Function for a --
DELIMITER ;;

CREATE FUNCTION armor_total(character_id INT)
RETURNS INT
DETERMINISTIC
BEGIN
    -- Declare variables for base armor and equipped armor -- 
    DECLARE base_armor INT DEFAULT 0;
    DECLARE equipped_armor INT DEFAULT 0;

    -- Get base armor from character_stats --
    SELECT COALESCE(armor, 0) INTO base_armor
    FROM character_stats
    WHERE character_id = character_id;

    -- Get total armor from equipped items --
    SELECT COALESCE(SUM(armor), 0) INTO equipped_armor
    FROM items
    WHERE item_id IN (
        SELECT item_id
        FROM equipped
        WHERE character_id = character_id
    );

    -- Return the sum of base armor and equipped armor --
    RETURN base_armor + equipped_armor;
END;;

DELIMITER ;

-- create procedures for characgters -- 
DELIMITER ;;

CREATE PROCEDURE attack(IN id_of_character_being_attacked DEFAULT 0 ,IN id_of_equipped_item_used_for_attack DEFAULT 0)
  
DECLARE armor INT DEFAULT 0;
DECLARE damage INT DEFAULT 0;
DECLARE effective_damage INT DEFAULT 0;
DECLARE current_health INT DEFAULT 0;
DECLARE new_health INT DEFAULT 0;

SET armor = armor_total(id_of_character_being_attacked);

--attacking item damage --
SELECT damage INTO damage
FROM items
WHERE item_id = d_of_equipped_item_used_for_attack

-- calc effective damage --
 SET effective_damage = damage - armor;
-- if statement to make sure that the ED is negative so no damage delt
 IF effective_damage <= 0 THEN
        LEAVE attack;
    END IF;

-- current health of attacked player -- 
 SELECT health INTO current_health
    FROM character_stats
    WHERE character_id = id_of_character_being_attacked;

-- calc new health of player -- 
SET new_health = current_health - effective_damage;

--Delete player from the user base -- 

 IF new_health > 0 THEN
        -- Character survives, update their health
        UPDATE character_stats
        SET health = new_health
        WHERE character_id = id_of_character_being_attacked;
    ELSE
        -- Character dies, remove them and their related data
        DELETE FROM characters WHERE character_id = id_of_character_being_attacked;
        DELETE FROM character_stats WHERE character_id = id_of_character_being_attacked;
        DELETE FROM inventory WHERE character_id = id_of_character_being_attacked;
        DELETE FROM equipped WHERE character_id = id_of_character_being_attacked;
        DELETE FROM team_members WHERE character_id = id_of_character_being_attacked;
    END IF;
END;;

DELIMITER ;
