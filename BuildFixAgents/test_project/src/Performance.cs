namespace TestProject;

public class PerformanceIssue
{
    public void InefficientLoop()
    {
        var list = new List<int>();
        for (int i = 0; i < 1000000; i++)
        {
            if (list.Any(x => x == i))  // O(n) inside O(n) loop
            {
                // Do something
            }
        }
    }
}
