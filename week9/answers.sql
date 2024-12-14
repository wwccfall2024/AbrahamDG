-- Create your tables, views, functions and procedures here!
CREATE SCHEMA social;
USE social;



CREATE TABLE users(
user_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
first_name VARCHAR(50) NOT NULL,
last_name VARCHAR(50) NOT NULL,
email VARCHAR(100) NOT NULL,
created_on TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE sessions(
session_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
user_id INT UNSIGNED NOT NULL, 
created_on TIMESTAMP NOT NULL DEFAULT NOW(),
updated_on TIMESTAMP NOT NULL DEFAULT NOW() ON UPDATE NOW(),
CONSTRAINT fk_sessions_userID FOREIGN KEY (user_id) REFERENCES users(user_id) 
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

CREATE TABLE friends(
user_friend_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
user_id INT UNSIGNED,
friend_id INT UNSIGNED,
CONSTRAINT fk_friends_user_id FOREIGN KEY (user_id) REFERENCES users(user_id) 
    ON DELETE CASCADE
    ON UPDATE CASCADE,
CONSTRAINT fk_friends_friends_id FOREIGN KEY (friend_id) REFERENCES users(user_id) 
    ON DELETE CASCADE
    ON UPDATE CASCADE
);


CREATE TABLE posts (
    post_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    user_id INT UNSIGNED NOT NULL,
    content VARCHAR(250) NOT NULL,
    created_on TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_on TIMESTAMP NOT NULL DEFAULT NOW() ON UPDATE NOW(),
    CONSTRAINT fk_posts_user_id FOREIGN KEY (user_id) REFERENCES users(user_id) 
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE TABLE notifications(
notification_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
user_id INT UNSIGNED NOT NULL,
post_id INT UNSIGNED NOT NULL,
CONSTRAINT fk_notifications_user_id FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
CONSTRAINT fk_notifications_post FOREIGN KEY (post_id) REFERENCES posts(post_id) 
    ON DELETE CASCADE
    ON UPDATE CASCADE
);



-- notification view 
CREATE VIEW notification_posts AS
SELECT
    notif.user_id AS notification_user_id,
    u.first_name,
    u.last_name,
    p.post_id,
    p.content
FROM 
    notifications notif
INNER JOIN posts p ON notif.post_id = p.post_id
INNER JOIN users u ON p.user_id = u.user_id;




DELIMITER $$

CREATE TRIGGER after_user_insert
AFTER INSERT ON users
FOR EACH ROW
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE existing_user_id INT;

    -- Declare a cursor for iterating through existing users
    DECLARE user_cursor CURSOR FOR
    SELECT user_id FROM users WHERE user_id != NEW.user_id;

    -- Declare a NOT FOUND handler to exit the loop
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    -- Open the cursor
    OPEN user_cursor;

    user_loop: LOOP
        -- Fetch the next user ID
        FETCH user_cursor INTO existing_user_id;

        -- Exit the loop if there are no more rows
        IF done THEN
            LEAVE user_loop;
        END IF;

        -- Insert a notification for the existing user
        INSERT INTO notifications (user_id, post_id)
        VALUES (existing_user_id, NULL);
    END LOOP;

    -- Close the cursor
    CLOSE user_cursor;

    -- Insert a post for the new user
    INSERT INTO posts (user_id, content)
    VALUES (
        NEW.user_id,
        CONCAT(NEW.first_name, ' ', NEW.last_name, ' just joined!')
    );

    -- Notify the new user's friends
    INSERT INTO notifications (user_id, post_id)
    SELECT friend_id, LAST_INSERT_ID()
    FROM friends
    WHERE user_id = NEW.user_id;
END$$

    

CREATE PROCEDURE add_post(IN user_id INT, IN content VARCHAR(250))
BEGIN
    DECLARE new_post_id INT;

    -- Insert the new post into the posts table
    INSERT INTO posts (user_id, content, created_on, updated_on)
    VALUES (user_id, content, NOW(), NOW());

    -- Get the post_id of the newly inserted post
    SET new_post_id = LAST_INSERT_ID();

    -- Create notifications for all friends of the user
    INSERT INTO notifications (user_id, post_id)
    SELECT friend_id, new_post_id
    FROM friends
    WHERE user_id = add_post.user_id;

END$$


CREATE EVENT Delete_Old_Sessions_Event
ON SCHEDULE EVERY 1 HOUR
DO
BEGIN
    DELETE FROM sessions
    WHERE updated_on < NOW() - INTERVAL 2 HOUR;
END$$


DELIMITER ;


