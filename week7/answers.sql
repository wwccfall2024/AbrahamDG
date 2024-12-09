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

DELIMITER $$
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
LEFT JOIN items i ON i.item_id = combined_items.item_id;

CREATE OR REPLACE VIEW team_items AS
SELECT DISTINCT
    t.team_id,
    t.name AS team_name,
    c.character_id,
    c.name AS character_name,
    i.name AS item_name,
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
LEFT JOIN items i ON i.item_id = combined_items.item_id;


-- Function for armor
CREATE FUNCTION armor_total(char_id INT)
RETURNS INT
DETERMINISTIC
BEGIN
    -- Declare variables for base armor and equipped armor
    DECLARE character_stats_armor INT DEFAULT 0;
    DECLARE equipped_armor INT DEFAULT 0;
    DECLARE total_armor INT DEFAULT 0;

    -- Get base armor from character_stats
    SELECT COALESCE(armor, 0) INTO character_stats_armor
    FROM character_stats
    WHERE character_id = char_id;

    -- Get total armor from equipped items
    SELECT COALESCE(SUM(armor), 0) INTO equipped_armor
    FROM items
    WHERE item_id IN (
        SELECT item_id
        FROM equipped
        WHERE character_id = char_id
    );

    -- Return the sum of base armor and equipped armor
    SET total_armor = character_stats_armor + equipped_armor;
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
  DECLARE current_health INT DEFAULT 0;
  DECLARE new_health INT DEFAULT 0;

  SET armor = armor_total(id_of_character_being_attacked);

  -- Attacking item damage
  SELECT items.damage INTO damage
  FROM items
  WHERE items.item_id = id_of_equipped_item_used_for_attack;

  -- Calculate effective damage
  SET effective_damage = damage - armor;

  -- Only proceed if effective damage is positive
  IF effective_damage > 0 THEN
    SELECT health INTO current_health
    FROM character_stats
    WHERE character_id = id_of_character_being_attacked;

    -- Calculate new health of the character
    SET new_health = current_health - effective_damage;

    -- Update health or delete character if they die
    IF new_health > 0 THEN
      UPDATE character_stats
      SET health = new_health
      WHERE character_id = id_of_character_being_attacked;
    ELSE
      DELETE FROM inventory WHERE character_id = id_of_character_being_attacked;
      DELETE FROM equipped WHERE character_id = id_of_character_being_attacked;
      DELETE FROM team_members WHERE character_id = id_of_character_being_attacked;
      DELETE FROM character_stats WHERE character_id = id_of_character_being_attacked;
      DELETE FROM characters WHERE character_id = id_of_character_being_attacked;
    END IF;
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


CREATE OR REPLACE PROCEDURE set_winners (IN team_id INT)
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
