using System.Data.SqlClient;

namespace TestProject;

public class SecurityIssue
{
    private string connectionString = "Server=localhost;Database=test;User Id=sa;Password=MyPassword123!";  // Hardcoded password
    
    public void SqlInjection(string input)
    {
        string query = "SELECT * FROM Users WHERE Name = '" + input + "'";  // SQL injection
        // Execute query
    }
}
