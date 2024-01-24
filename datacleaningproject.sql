use cleaning_projects;
select *
from cleaning_projects.nashvillehousing;
-- This is a Data Cleaning project guided by Alex the Analyst. This project is meant to hone my data cleaning skills in SQL.
-- I had a bit of trouble importing the data because a lot of the columns were blank. So I replaced all of the blanks with NULL. 
-- Now the data is sucessfully imported, we can start the project! 

-- Standardizing SaleDate
select SaleDate
from cleaning_projects.nashvillehousing;
-- Date is formated as Day-Month-Year (ex. 9-Apr-13), gonna format it as the typical Day/Month/Year (ex. 09/04/2013)

SET SQL_SAFE_UPDATES = 0; -- Disable safe update mode temporarily

UPDATE nashvillehousing
SET SaleDate = DATE_FORMAT(STR_TO_DATE(SaleDate, '%d-%b-%y'), '%d/%m/%Y')
WHERE SaleDate IS NOT NULL;

SET SQL_SAFE_UPDATES = 1; -- Re-enable safe update mode

-- Checking if that worked 
select SaleDate
from cleaning_projects.nashvillehousing;
-- It worked! It's in the right format! 

-- Populate Property Address Data

select *
from cleaning_projects.nashvillehousing
where PropertyAddress is null;

-- There's a lot of null values in the PropertyAddress Column
-- Self joining to see if the same parcel id's share an address in some columns.  

select a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress
from cleaning_projects.nashvillehousing a
join cleaning_projects.nashvillehousing b
on a.ParcelID = b.ParcelID
and a.UniqueID != b.UniqueID
where a.PropertyAddress is null;

-- The same parcel ID that contains null values in the Propertyaddress columns have address in different rows, meaning there shouldn't be any null values. 
-- Updating away the null values

SET SQL_SAFE_UPDATES = 0; -- Disable safe update mode temporarily
UPDATE cleaning_projects.nashvillehousing a
JOIN cleaning_projects.nashvillehousing b ON a.ParcelID = b.ParcelID AND a.UniqueID != b.UniqueID
SET a.PropertyAddress = IFNULL(a.PropertyAddress, b.PropertyAddress)
WHERE a.PropertyAddress IS NULL;
SET SQL_SAFE_UPDATES = 1; -- Re-enable safe update mode

-- Checking if it worked. 
select *
from cleaning_projects.nashvillehousing
where PropertyAddress is null;
-- Got no nulls, the PropertyAddress is populated!

-- Breaking the Address into individual columns (Address, City, State)
select PropertyAddress
from cleaning_projects.nashvillehousing;

-- Using substring to break it apart from the , 

SELECT
    PropertyAddress,
    SUBSTRING_INDEX(PropertyAddress, ',', 1) AS SplitPropertyAddress,
    SUBSTRING_INDEX(PropertyAddress, ',', -1) AS SplitPropertyCity
FROM
    cleaning_projects.nashvillehousing;
-- This code works, time to update the table. 
    
ALTER TABLE cleaning_projects.nashvillehousing
ADD COLUMN SplitPropertyAddress VARCHAR(255),
ADD COLUMN SplitPropertyCity VARCHAR(255);

SET SQL_SAFE_UPDATES = 0; -- Disable safe update mode temporarily
UPDATE cleaning_projects.nashvillehousing
SET
    SplitPropertyAddress = SUBSTRING_INDEX(PropertyAddress, ',', 1),
    SplitPropertyCity = SUBSTRING_INDEX(PropertyAddress, ',', -1);
SET SQL_SAFE_UPDATES = 1; -- Re-enable safe update mode

-- Checking if it worked
select SplitPropertyAddress, SplitPropertyCity
from cleaning_projects.nashvillehousing;
-- It worked!!

-- Doing the same for the OwnerAddress Column which is formated (Address, City, State)
-- Add new columns for Address, City, and State
ALTER TABLE cleaning_projects.nashvillehousing
ADD COLUMN OwnerSplit_Address VARCHAR(255),
ADD COLUMN OwnerSplit_City VARCHAR(255),
ADD COLUMN OwnerSplit_State VARCHAR(255);

-- Update values in the new columns
SET SQL_SAFE_UPDATES = 0; -- Disable safe update mode temporarily
UPDATE cleaning_projects.nashvillehousing
SET
    OwnerSplit_Address = SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress, ',', 1), '(', -1),
    OwnerSplit_City = SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress, ',', 2), ',', -1),
    OwnerSplit_State = TRIM(TRAILING ')' FROM SUBSTRING_INDEX(OwnerAddress, ',', -1));
SET SQL_SAFE_UPDATES = 1; -- Re-enable safe update mode
-- Optional: Remove original OwnerAddress column
-- ALTER TABLE your_table_name
-- DROP COLUMN OwnerAddress;

-- Checking if it worked
select *
from cleaning_projects.nashvillehousing;
-- It worked!

-- Changing Y and N to Yes and No in SoldAsVacant column
select distinct(SoldAsVacant), count(SoldAsVacant)
from cleaning_projects.nashvillehousing
group by SoldAsVacant
order by 2;
-- there's a couple of Y and Ns in a column that mostly contains Yes's and No's, I'm going to standardize them. 

SET SQL_SAFE_UPDATES = 0; -- Disable safe update mode temporarily
UPDATE cleaning_projects.nashvillehousing
SET SoldAsVacant = CASE 
                      WHEN SoldAsVacant = 'Y' THEN 'Yes'
                      WHEN SoldAsVacant = 'N' THEN 'No'
                      ELSE SoldAsVacant
                   END;
SET SQL_SAFE_UPDATES = 1; -- Re-enable safe update mode

-- Checking if it worked
select distinct(SoldAsVacant), count(SoldAsVacant)
from cleaning_projects.nashvillehousing
group by SoldAsVacant
order by 2;
-- It worked!!

-- Removing duplicates
-- Going to save a csv file of the data we have so far as a backup. Since we're going to be deleting the duplicates. 
select *
from cleaning_projects.nashvillehousing;

-- In this data set there's a column titled "UniqueID", every entry here is supposed to be unique, going to check for duplicates in this column. 
SELECT UniqueID, COUNT(*)
FROM cleaning_projects.nashvillehousing
GROUP BY UniqueID
HAVING COUNT(*) > 1;
-- There are no duplicates in the UniqueID, time to do the same for other columns that shouldn't have duplicates. 

-- The video has us using CTE

WITH RowNumCTE AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY ParcelID,
                            PropertyAddress,
                            SalePrice,
                            SaleDate,
                            LegalReference
               ORDER BY UniqueID
           ) AS row_num
    FROM cleaning_projects.nashvillehousing
)
SELECT *
FROM RowNumCTE
where row_num > 1
order by PropertyAddress;

-- there's a couple of duplicates, time to get rid of them. 
-- Disable safe update mode temporarily
SET SQL_SAFE_UPDATES = 0;

-- Use CTE to identify rows to delete
WITH RowNumCTE AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY ParcelID,
                            PropertyAddress,
                            SalePrice,
                            SaleDate,
                            LegalReference
               ORDER BY UniqueID
           ) AS row_num
    FROM cleaning_projects.nashvillehousing
)
DELETE FROM cleaning_projects.nashvillehousing
WHERE (ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference, UniqueID) IN (
    SELECT ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference, UniqueID
    FROM RowNumCTE
    WHERE row_num > 1
);

-- Re-enable safe update mode
SET SQL_SAFE_UPDATES = 1;
-- Checked it, and it worked, no duplicates!

-- Deleting unused columns
select * 
from cleaning_projects.nashvillehousing;
-- the only useless columns now are OwnerAddress and Property Address

ALTER TABLE cleaning_projects.nashvillehousing
DROP COLUMN PropertyAddress;

ALTER TABLE cleaning_projects.nashvillehousing
DROP COLUMN OwnerAddress;

-- Now, the data is all cleaned!! Project complete!