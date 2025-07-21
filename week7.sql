-- SCD Type 0: Do Nothing (Fixed Dimension)
DELIMITER //

CREATE PROCEDURE SCD_Type_0()
BEGIN
    INSERT INTO CustomerDim (CustomerID, CustomerName, City, Email)
    SELECT s.CustomerID, s.CustomerName, s.City, s.Email
    FROM CustomerStaging s
    WHERE NOT EXISTS (
        SELECT 1 FROM CustomerDim d WHERE d.CustomerID = s.CustomerID
    );
END //

-- SCD Type 1: Overwrite without keeping history
CREATE PROCEDURE SCD_Type_1()
BEGIN
    UPDATE CustomerDim d
    JOIN CustomerStaging s ON d.CustomerID = s.CustomerID
    SET d.CustomerName = s.CustomerName,
        d.City = s.City,
        d.Email = s.Email;

    INSERT INTO CustomerDim (CustomerID, CustomerName, City, Email)
    SELECT s.CustomerID, s.CustomerName, s.City, s.Email
    FROM CustomerStaging s
    WHERE NOT EXISTS (
        SELECT 1 FROM CustomerDim d WHERE d.CustomerID = s.CustomerID
    );
END //

-- SCD Type 2: Full History Tracking with IsCurrent flag
CREATE PROCEDURE SCD_Type_2()
BEGIN
    UPDATE CustomerDim d
    JOIN CustomerStaging s ON d.CustomerID = s.CustomerID AND d.IsCurrent = 1
    SET d.IsCurrent = 0,
        d.EndDate = CURRENT_DATE
    WHERE d.CustomerName <> s.CustomerName
       OR d.City <> s.City
       OR d.Email <> s.Email;

    INSERT INTO CustomerDim (CustomerID, CustomerName, City, Email, StartDate, EndDate, IsCurrent)
    SELECT s.CustomerID, s.CustomerName, s.City, s.Email, CURRENT_DATE, NULL, 1
    FROM CustomerStaging s
    WHERE EXISTS (
        SELECT 1 FROM CustomerDim d
        WHERE d.CustomerID = s.CustomerID
          AND d.IsCurrent = 1
          AND (d.CustomerName <> s.CustomerName OR d.City <> s.City OR d.Email <> s.Email)
    );

    INSERT INTO CustomerDim (CustomerID, CustomerName, City, Email, StartDate, EndDate, IsCurrent)
    SELECT s.CustomerID, s.CustomerName, s.City, s.Email, CURRENT_DATE, NULL, 1
    FROM CustomerStaging s
    WHERE NOT EXISTS (
        SELECT 1 FROM CustomerDim d WHERE d.CustomerID = s.CustomerID
    );
END //

-- SCD Type 3: Partial History (e.g. PreviousCity)
CREATE PROCEDURE SCD_Type_3()
BEGIN
    UPDATE CustomerDim d
    JOIN CustomerStaging s ON d.CustomerID = s.CustomerID
    SET d.PreviousCity = d.City,
        d.City = s.City
    WHERE d.City <> s.City;

    INSERT INTO CustomerDim (CustomerID, CustomerName, City, PreviousCity, Email)
    SELECT s.CustomerID, s.CustomerName, s.City, NULL, s.Email
    FROM CustomerStaging s
    WHERE NOT EXISTS (
        SELECT 1 FROM CustomerDim d WHERE d.CustomerID = s.CustomerID
    );
END //

-- SCD Type 4: History in Separate Table
CREATE PROCEDURE SCD_Type_4()
BEGIN
    INSERT INTO CustomerHistory (CustomerID, CustomerName, City, Email, ChangeDate)
    SELECT d.CustomerID, d.CustomerName, d.City, d.Email, CURRENT_DATE
    FROM CustomerDim d
    JOIN CustomerStaging s ON d.CustomerID = s.CustomerID
    WHERE d.CustomerName <> s.CustomerName
       OR d.City <> s.City
       OR d.Email <> s.Email;

    UPDATE CustomerDim d
    JOIN CustomerStaging s ON d.CustomerID = s.CustomerID
    SET d.CustomerName = s.CustomerName,
        d.City = s.City,
        d.Email = s.Email;

    INSERT INTO CustomerDim (CustomerID, CustomerName, City, Email)
    SELECT s.CustomerID, s.CustomerName, s.City, s.Email
    FROM CustomerStaging s
    WHERE NOT EXISTS (
        SELECT 1 FROM CustomerDim d WHERE d.CustomerID = s.CustomerID
    );
END //

-- SCD Type 6: Hybrid of Type 1, 2, and 3
CREATE PROCEDURE SCD_Type_6()
BEGIN
    UPDATE CustomerDim d
    JOIN CustomerStaging s ON d.CustomerID = s.CustomerID AND d.IsCurrent = 1
    SET d.IsCurrent = 0,
        d.EndDate = CURRENT_DATE
    WHERE d.City <> s.City;

    INSERT INTO CustomerDim (CustomerID, CustomerName, City, PreviousCity, Email, StartDate, EndDate, IsCurrent)
    SELECT s.CustomerID, s.CustomerName, s.City, d.City, s.Email, CURRENT_DATE, NULL, 1
    FROM CustomerStaging s
    JOIN CustomerDim d ON s.CustomerID = d.CustomerID
    WHERE d.IsCurrent = 0
      AND d.City <> s.City;

    INSERT INTO CustomerDim (CustomerID, CustomerName, City, PreviousCity, Email, StartDate, EndDate, IsCurrent)
    SELECT s.CustomerID, s.CustomerName, s.City, NULL, s.Email, CURRENT_DATE, NULL, 1
    FROM CustomerStaging s
    WHERE NOT EXISTS (
        SELECT 1 FROM CustomerDim d WHERE d.CustomerID = s.CustomerID
    );
END //

DELIMITER ;
