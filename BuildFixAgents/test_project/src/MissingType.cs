namespace TestProject;

public class MissingTypeExample
{
    private NonExistentType field;  // CS0246
    
    public void UseType()
    {
        var x = new AnotherMissingType();  // CS0246
    }
}
