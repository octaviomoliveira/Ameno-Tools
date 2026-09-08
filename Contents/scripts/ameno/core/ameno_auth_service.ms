/*
    Ameno Tools - Servico de autenticacao Supabase

    Responsabilidades:
    - Login / logout via REST API do Supabase Auth
    - Armazenamento seguro do token via DPAPI do Windows
      (criptografa com a chave da conta Windows do usuario)
    - Validacao de expiracao + refresh automatico
    - Machine ID baseado em hardware (sem instalar nada)
    - Modo tolerante: funciona offline por ate 7 dias com token local

    IMPORTANTE: substitua SUPABASE_URL e SUPABASE_ANON_KEY com os
    valores do seu projeto em supabase.com -> Settings -> API.
*/

global AmenoAuthService
global AmenoAuthResult

struct AmenoAuthResultDef
(
    ok          = false,
    error       = "",
    token       = "",
    expiresAt   = 0,
    userId      = "",
    email       = "",
    plan        = "trial"
)
AmenoAuthResult = AmenoAuthResultDef

struct AmenoAuthServiceDefinition
(
    -- Configuracao -- substitua com os valores do seu projeto Supabase
    SUPABASE_URL      = "https://SUBSTITUA.supabase.co",
    SUPABASE_ANON_KEY = "SUBSTITUA_PELA_ANON_KEY",

    -- Tolerancia offline: token local e aceito por este numero de dias
    OFFLINE_GRACE_DAYS = 7,

    -- Retorna o caminho do arquivo de sessao criptografada
    fn _sessionFilePath =
    (
        local appData = dotNetClass "System.Environment"
        local folder  = appData.GetFolderPath (appData.SpecialFolder.ApplicationData)
        local dirPath = (dotNetClass "System.IO.Path").Combine folder "AmenoTools"
        (dotNetClass "System.IO.Directory").CreateDirectory dirPath
        (dotNetClass "System.IO.Path").Combine dirPath "session.enc"
    ),

    -- Gera machine ID estavela baseado no hostname + processador
    fn _getMachineId =
    (
        local env  = dotNetClass "System.Environment"
        local host = env.MachineName
        local cpu  = ""
        try
        (
            local wmi = dotNetObject "System.Management.ManagementObjectSearcher" \
                "SELECT ProcessorId FROM Win32_Processor"
            local col = wmi.Get()
            local en  = col.GetEnumerator()
            if en.MoveNext() do
                cpu = (en.Current.get_Item "ProcessorId") as string
        )
        catch ()
        local raw   = host + "|" + cpu
        local sha   = (dotNetClass "System.Security.Cryptography.SHA256").Create()
        local bytes = (dotNetClass "System.Text.Encoding").UTF8.GetBytes raw
        local hash  = sha.ComputeHash bytes
        local sb    = dotNetObject "System.Text.StringBuilder"
        for b in hash do sb.AppendFormat "{0:x2}" b
        sb.ToString()
    ),

    fn _encrypt plainText =
    (
        local dpapi = dotNetClass "System.Security.Cryptography.ProtectedData"
        local bytes = (dotNetClass "System.Text.Encoding").UTF8.GetBytes plainText
        local scope = (dotNetClass "System.Security.Cryptography.DataProtectionScope").CurrentUser
        dpapi.Protect bytes undefined scope
    ),

    fn _decrypt encBytes =
    (
        local dpapi = dotNetClass "System.Security.Cryptography.ProtectedData"
        local scope = (dotNetClass "System.Security.Cryptography.DataProtectionScope").CurrentUser
        local plain = dpapi.Unprotect encBytes undefined scope
        (dotNetClass "System.Text.Encoding").UTF8.GetString plain
    ),

    fn _saveSession json =
    (
        local path = _sessionFilePath()
        try
        (
            local enc = _encrypt json
            (dotNetClass "System.IO.File").WriteAllBytes path enc
            true
        )
        catch false
    ),

    fn _loadSession =
    (
        local path = _sessionFilePath()
        if not ((dotNetClass "System.IO.File").Exists path) then return ""
        try
        (
            local enc = (dotNetClass "System.IO.File").ReadAllBytes path
            _decrypt enc
        )
        catch ""
    ),

    -- Parser JSON minimo: extrai valor de "key":"value"
    fn _jsonGetString json key =
    (
        local pattern = "\"" + key + "\":\""
        local idx = findString json pattern
        if idx == 0 then return ""
        local start = idx + pattern.count
        local rest  = substring json start (json.count - start + 1)
        local endQ  = findString rest "\""
        if endQ == 0 then return ""
        substring rest 1 (endQ - 1)
    ),

    fn _jsonGetNumber json key =
    (
        local pattern = "\"" + key + "\":"
        local idx = findString json pattern
        if idx == 0 then return 0
        local start = idx + pattern.count
        local rest  = substring json start (json.count - start + 1)
        local endIdx = rest.count
        for c in #(",", "}", "]", " ", "\n", "\r") do
        (
            local ci = findString rest c
            if ci > 0 and ci < endIdx do endIdx = ci - 1
        )
        local numStr = trimRight (trimLeft (substring rest 1 endIdx))
        try (execute numStr) catch 0
    ),

    fn _httpPost url bodyJson extraHeaders =
    (
        local result = ""
        try
        (
            local client = dotNetObject "System.Net.WebClient"
            client.Headers.Add "Content-Type" "application/json"
            client.Headers.Add "apikey" SUPABASE_ANON_KEY
            for h in extraHeaders do client.Headers.Add h[1] h[2]
            result = client.UploadString url bodyJson
        )
        catch ()
        result
    ),

    fn _httpGet url token =
    (
        local result = ""
        try
        (
            local client = dotNetObject "System.Net.WebClient"
            client.Headers.Add "apikey" SUPABASE_ANON_KEY
            client.Headers.Add "Authorization" ("Bearer " + token)
            result = client.DownloadString url
        )
        catch ()
        result
    ),

    fn _fetchPlan token userId =
    (
        local url  = SUPABASE_URL + "/rest/v1/profiles?id=eq." + userId + "&select=plan,active"
        local resp = _httpGet url token
        if resp == "" then return "trial"
        local activeStr = _jsonGetString resp "active"
        if activeStr == "false" then return "suspended"
        local plan = _jsonGetString resp "plan"
        if plan == "" then "trial" else plan
    ),

    fn _registerMachine token userId =
    (
        local machineId   = _getMachineId()
        local machineName = (dotNetClass "System.Environment").MachineName
        local url  = SUPABASE_URL + "/rest/v1/machines"
        local body = "{\"user_id\":\"" + userId + "\"," + \
                     "\"machine_id\":\"" + machineId + "\"," + \
                     "\"machine_name\":\"" + machineName + "\"}"
        try
        (
            local client = dotNetObject "System.Net.WebClient"
            client.Headers.Add "Content-Type" "application/json"
            client.Headers.Add "apikey" SUPABASE_ANON_KEY
            client.Headers.Add "Authorization" ("Bearer " + token)
            client.Headers.Add "Prefer" "resolution=merge-duplicates"
            client.UploadString url body
        )
        catch ()
        true
    ),

    fn _loadOfflineSession =
    (
        local r    = AmenoAuthResultDef()
        local json = _loadSession()
        if json == "" then
        (
            r.error = "Sem conexao com o servidor e nenhuma sessao salva encontrada."
            return r
        )
        local savedAt     = _jsonGetNumber json "saved_at"
        local nowTicks    = (dotNetClass "System.DateTime").UtcNow.Ticks
        local ticksPerDay = 864000000000 -- ticks por dia
        local daysPassed  = (nowTicks - savedAt) / ticksPerDay
        if daysPassed > OFFLINE_GRACE_DAYS then
        (
            r.error = "Sem conexao e a sessao offline expirou (" + (daysPassed as string) + " dias). Conecte a internet."
            return r
        )
        r.ok        = true
        r.token     = _jsonGetString json "access_token"
        r.expiresAt = _jsonGetNumber json "expires_ticks"
        r.userId    = _jsonGetString json "user_id"
        r.email     = _jsonGetString json "email"
        r.plan      = _jsonGetString json "plan"
        r
    ),

    /*  login email password -> AmenoAuthResultDef  */
    fn login email password =
    (
        local r = AmenoAuthResultDef()
        if email == "" or password == "" then
        (
            r.error = "Informe e-mail e senha."
            return r
        )
        local url  = SUPABASE_URL + "/auth/v1/token?grant_type=password"
        local body = "{\"email\":\"" + email + "\",\"password\":\"" + password + "\"}"
        local resp = _httpPost url body #()
        if resp == "" then return _loadOfflineSession()

        local errMsg = _jsonGetString resp "error_description"
        if errMsg == "" do errMsg = _jsonGetString resp "msg"
        if errMsg == "" do errMsg = _jsonGetString resp "error"
        if errMsg != "" then
        (
            r.error = errMsg
            return r
        )

        local accessToken = _jsonGetString resp "access_token"
        local expiresIn   = _jsonGetNumber resp "expires_in"
        local userId      = ""
        local userStart   = findString resp "\"user\":"
        if userStart > 0 then
        (
            local userJson = substring resp userStart (resp.count - userStart + 1)
            userId = _jsonGetString userJson "id"
        )
        if accessToken == "" then
        (
            r.error = "Resposta invalida do servidor."
            return r
        )
        local nowDt    = dotNetClass "System.DateTime"
        local expTicks = (nowDt.UtcNow.AddSeconds (expiresIn as float)).Ticks
        local plan     = _fetchPlan accessToken userId

        if plan == "suspended" then
        (
            r.error = "Conta suspensa. Entre em contato com o suporte."
            return r
        )

        local nowTicks    = nowDt.UtcNow.Ticks
        local sessionJson = "{" + \
            "\"access_token\":\"" + accessToken + "\"," + \
            "\"expires_ticks\":" + (expTicks as string) + "," + \
            "\"user_id\":\"" + userId + "\"," + \
            "\"email\":\"" + email + "\"," + \
            "\"plan\":\"" + plan + "\"," + \
            "\"saved_at\":" + (nowTicks as string) + \
        "}"
        _saveSession sessionJson
        _registerMachine accessToken userId

        r.ok        = true
        r.token     = accessToken
        r.expiresAt = expTicks
        r.userId    = userId
        r.email     = email
        r.plan      = plan
        r
    ),

    /*  isAuthenticated -> bool  */
    fn isAuthenticated =
    (
        local json = _loadSession()
        if json == "" then return false
        local expTicks    = _jsonGetNumber json "expires_ticks"
        local savedAt     = _jsonGetNumber json "saved_at"
        local nowTicks    = (dotNetClass "System.DateTime").UtcNow.Ticks
        local ticksPerDay = 864000000000
        if nowTicks < expTicks then return true
        local daysPassed = (nowTicks - savedAt) / ticksPerDay
        daysPassed <= OFFLINE_GRACE_DAYS
    ),

    /*  getSession -> AmenoAuthResultDef (sem chamada de rede)  */
    fn getSession =
    (
        local r    = AmenoAuthResultDef()
        local json = _loadSession()
        if json == "" then return r
        r.ok        = true
        r.token     = _jsonGetString json "access_token"
        r.expiresAt = _jsonGetNumber json "expires_ticks"
        r.userId    = _jsonGetString json "user_id"
        r.email     = _jsonGetString json "email"
        r.plan      = _jsonGetString json "plan"
        r
    ),

    /*  logout -> apaga a sessao local  */
    fn logout =
    (
        local path = _sessionFilePath()
        try
        (
            if (dotNetClass "System.IO.File").Exists path do
                (dotNetClass "System.IO.File").Delete path
        )
        catch ()
        true
    )
)

AmenoAuthService = AmenoAuthServiceDefinition()