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
  level TINYINT UNSIGNED,
  CONSTRAINT fk_characters_player FOREIGN KEY (player_id) REFERENCES players(player_id)
);

CREATE TABLE winners(
  character_id INT UNSIGNED NOT NULL,
  name VARCHAR(30) NOT NULL,
  CONSTRAINT fk_winners_character FOREIGN KEY (character_id) REFERENCES characters(character_id)
  ON DELETE CASCADE
);

CREATE TABLE character_stats(
  character_id INT UNSIGNED NOT NULL,
  health TINYINT UNSIGNED,
  armor TINYINT UNSIGNED,
  CONSTRAINT fk_character_stats_stats FOREIGN KEY (character_id) REFERENCES characters(character_id)
  ON DELETE CASCADE
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
  ON DELETE CASCADE
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
  CONSTRAINT fk_inventory_characters FOREIGN KEY (character_id) REFERENCES characters(character_id) ON DELETE CASCADE,
  CONSTRAINT fk_inventory_items FOREIGN KEY (item_id) REFERENCES items(item_id)
);
CREATE TABLE equipped(
  equipped_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
  character_id INT UNSIGNED NOT NULL,
  item_id INT UNSIGNED NOT NULL,
  CONSTRAINT fk_equipped_characters FOREIGN KEY (character_id) REFERENCES characters(character_id) ON DELETE CASCADE,
  CONSTRAINT fk_equipped_items FOREIGN KEY (item_id) REFERENCES items(item_id)
);

CREATE OR REPLACE VIEW character_items AS 
SELECT 
    c.character_id,
    c.name AS character_name,
    i.item_id,
    i.name AS item_name,
    i.armor,
    i.damage
FROM characters c
LEFT JOIN (
    SELECT DISTINCT item_id, character_id
    FROM inventory
    UNION 
    SELECT DISTINCT item_id, character_id
    FROM equipped
) AS combined_items ON c.character_id = combined_items.character_id
LEFT JOIN items i ON i.item_id = combined_items.item_id
ORDER BY c.character_id, i.name;


CREATE OR REPLACE VIEW team_items AS
SELECT DISTINCT
    t.team_id,
    t.name AS team_name,
    c.character_id,
    c.name AS character_name,
    COALESCE(i.name, '') AS item_name,
    i.armor,
    i.damage
FROM teams t
INNER JOIN team_members tm ON t.team_id = tm.team_id
INNER JOIN characters c ON tm.character_id = c.character_id
LEFT JOIN (
    SELECT item_id, character_id
    FROM inventory
    UNION
    SELECT item_id, character_id
    FROM equipped
) AS combined_items ON c.character_id = combined_items.character_id
LEFT JOIN items i ON i.item_id = combined_items.item_id
ORDER BY t.team_id, i.name;


-- Function for armor
DELIMITER $$

CREATE FUNCTION armor_total(character_id INT)
RETURNS INT
DETERMINISTIC
BEGIN
    -- Declare variables for base armor and equipped armor
    DECLARE base_armor INT DEFAULT 0;
    DECLARE equipped_armor INT DEFAULT 0;
    DECLARE total_armor INT DEFAULT 0;

    -- Get base armor from character_stats
    SELECT SUM(cs.armor) INTO base_armor
    FROM character_stats cs
    WHERE cs.character_id = character_id;

    -- Get total armor from equipped items
    SELECT SUM(i.armor) INTO equipped_armor
    FROM equipped e
    INNER JOIN items i
      ON e.item_id = i.item_id
    WHERE e.character_id = character_id;

    -- Calculate total armor
    SET total_armor = base_armor + equipped_armor;
    RETURN total_armor;
END$$

  
-- Procedures
CREATE PROCEDURE attack (
  IN id_of_character_being_attacked INT,
  IN id_of_equipped_item_used_for_attack INT
)
BEGIN
  DECLARE armor INT DEFAULT 0;
  DECLARE damage INT DEFAULT 0;
  DECLARE effective_damage INT DEFAULT 0;

  -- Get total armor for the character being attacked
  SET armor = armor_total(id_of_character_being_attacked);

  -- Get the damage value of the attacking item
  SELECT damage INTO damage
  FROM items
  WHERE item_id = id_of_equipped_item_used_for_attack;

  -- Calculate effective damage
  SET effective_damage = GREATEST(damage - armor, 0);

  -- Proceed only if effective damage is positive
  IF effective_damage > 0 THEN
    -- Update health or delete character if they die
    UPDATE character_stats
    SET health = health - effective_damage
    WHERE character_id = id_of_character_being_attacked;

    -- Delete character and related data if health is 0 or less
    DELETE FROM characters
    WHERE character_id = id_of_character_being_attacked
      AND (SELECT health FROM character_stats WHERE character_id = id_of_character_being_attacked) <= 0;
  END IF;
END$$

CREATE PROCEDURE equip (IN inventory_id INT)
BEGIN
    -- Insert the item from inventory into equipped
    INSERT INTO equipped (character_id, item_id)
    SELECT character_id, item_id
    FROM inventory inv
    WHERE inv.inventory_id = inventory_id;

    -- Delete the item from inventory
    DELETE FROM inventory
    WHERE inventory_id = inventory_id;
END$$

CREATE PROCEDURE unequip (IN equipped_id INT)
BEGIN
    INSERT INTO inventory (character_id, item_id)
    SELECT character_id, item_id
    FROM equipped eq
    WHERE eq.equipped_id = equipped_id;

    -- Delete from equipped
    DELETE FROM equipped
    WHERE equipped_id = equipped_id;
END$$


CREATE PROCEDURE set_winners (IN team_id INT)
BEGIN
    -- Declare variables for cursor
    DECLARE done INT DEFAULT 0;
    DECLARE char_id INT;
    DECLARE char_name VARCHAR(30);

    -- Declare a cursor for fetching team members
    DECLARE team_cursor CURSOR FOR
        SELECT c.character_id, c.name
        FROM team_members tm
        INNER JOIN characters c ON tm.character_id = c.character_id
        WHERE tm.team_id = team_id;

    -- Declare a handler for the end of the cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    -- Clear the winners table
    DELETE FROM winners;

    -- Open the cursor
    OPEN team_cursor;

    -- Loop through each character in the cursor
    FETCH team_cursor INTO char_id, char_name;

    WHILE done = 0 DO
        -- Insert the current character into the winners table
        INSERT INTO winners (character_id, name)
        VALUES (char_id, char_name);

        -- Fetch the next row
        FETCH team_cursor INTO char_id, char_name;
    END WHILE;

    -- Close the cursor
    CLOSE team_cursor;
END$$

DELIMITER ;
