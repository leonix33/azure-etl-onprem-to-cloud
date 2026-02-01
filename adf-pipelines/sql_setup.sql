-- Create Employees table in Azure SQL Database
CREATE TABLE dbo.Employees (
    EmployeeID INT PRIMARY KEY,
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    Department NVARCHAR(50),
    Salary DECIMAL(18, 2),
    HireDate DATE,
    LoadedDate DATETIME DEFAULT GETDATE(),
    CONSTRAINT UQ_EmployeeID UNIQUE (EmployeeID)
);

-- Create index for better query performance
CREATE INDEX IX_Employees_Department ON dbo.Employees(Department);
CREATE INDEX IX_Employees_HireDate ON dbo.Employees(HireDate);

-- View to check latest loaded data
CREATE VIEW vw_LatestEmployees AS
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    Department,
    Salary,
    HireDate,
    LoadedDate,
    DATEDIFF(DAY, LoadedDate, GETDATE()) AS DaysSinceLoad
FROM dbo.Employees;

-- Sample query to verify data
SELECT * FROM dbo.Employees ORDER BY LoadedDate DESC;

-- Summary by department
SELECT 
    Department,
    COUNT(*) AS EmployeeCount,
    AVG(Salary) AS AvgSalary,
    MIN(HireDate) AS EarliestHire,
    MAX(HireDate) AS LatestHire
FROM dbo.Employees
GROUP BY Department
ORDER BY Department;
