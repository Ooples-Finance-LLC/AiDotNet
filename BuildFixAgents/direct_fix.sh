#\!/bin/bash
# Direct fix for C# CS0104 errors

echo "Direct Fix - Applying pattern fixes for CS0104 errors"

# Fix IQuantizedModel ambiguous references
find . -name "*.cs" -type f -exec grep -l "IQuantizedModel<" {} \;  < /dev/null |  while read file; do
    echo "Fixing $file"
    sed -i 's/\bIQuantizedModel</AiDotNet.Interfaces.IQuantizedModel</g' "$file"
done

# Fix IPrunedModel ambiguous references  
find . -name "*.cs" -type f -exec grep -l "IPrunedModel<" {} \; | while read file; do
    echo "Fixing $file"
    sed -i 's/\bIPrunedModel</AiDotNet.Interfaces.IPrunedModel</g' "$file"
done

echo "Fixes applied. Running build to verify..."
dotnet build
