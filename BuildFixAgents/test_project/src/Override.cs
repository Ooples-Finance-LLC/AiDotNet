namespace TestProject;

public class BaseClass
{
    public virtual void Method1() { }
}

public class DerivedClass : BaseClass
{
    public override void Method2() { }  // CS0115
}
