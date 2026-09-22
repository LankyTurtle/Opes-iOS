$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$testBinary = Join-Path ([System.IO.Path]::GetTempPath()) ('opes-transactions-' + [guid]::NewGuid().ToString() + '.exe')
$sources = @(
    'Tests/Transactions/Support.swift',
    'Tests/Transactions/TransactionTests.swift',
    'Opes/Features/Accounts/Account.swift',
    'Opes/Features/Accounts/AccountStore.swift',
    'Opes/Features/Accounts/AccountFilter.swift',
    'Opes/Features/Accounts/BSBInput.swift',
    'Opes/Features/Transactions/Transaction.swift',
    'Opes/Features/Transactions/TransactionAmount.swift',
    'Opes/Features/Transactions/TransactionStore.swift',
    'Opes/Features/Transactions/TransactionCSVAttachment.swift',
    'Opes/Features/Transactions/TransactionCSVParser.swift'
) | ForEach-Object { Join-Path $repoRoot $_ }
try {
    & swiftc -swift-version 5 @sources -o $testBinary
    if ($LASTEXITCODE -ne 0) { throw 'Transaction checks did not compile.' }
    & $testBinary
    if ($LASTEXITCODE -ne 0) { throw 'Transaction checks failed.' }
} finally {
    foreach ($extension in @('.exe', '.lib', '.exp', '.pdb')) {
        $artifact = [System.IO.Path]::ChangeExtension($testBinary, $extension)
        if (Test-Path -LiteralPath $artifact) { Remove-Item -LiteralPath $artifact }
    }
}
