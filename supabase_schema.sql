-- ============================================================================
-- SHIFA MANAGEMENT - COMPLETE SUPABASE POSTGRESQL SCHEMA
-- Zero Cloud Functions | Automatic Sync | Row Level Security (RLS)
-- ============================================================================

-- 1. Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 2. USERS (PROFILES) TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT DEFAULT '',
    role TEXT NOT NULL CHECK (role IN ('admin', 'staff')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'deactivated', 'disabled', 'inactive')),
    organization_id TEXT DEFAULT 'default',
    is_internal_account BOOLEAN DEFAULT false,
    is_hidden BOOLEAN DEFAULT false,
    is_deleted BOOLEAN DEFAULT false,
    created_by TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deactivated_at TIMESTAMPTZ,
    reactivated_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_users_username ON public.users(username);
CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);
CREATE INDEX IF NOT EXISTS idx_users_status ON public.users(status);

-- ============================================================================
-- 3. PATIENTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.patients (
    id TEXT PRIMARY KEY,
    patient_name TEXT NOT NULL,
    mr_number TEXT NOT NULL,
    cnic TEXT DEFAULT '',
    phone TEXT DEFAULT '',
    address TEXT DEFAULT '',
    diagnosis TEXT DEFAULT '',
    doctor TEXT DEFAULT '',
    nurse TEXT DEFAULT '',
    caretaker TEXT DEFAULT '',
    patient_amount NUMERIC DEFAULT 0,
    staff_payment NUMERIC DEFAULT 0,
    monthly_service_cost NUMERIC DEFAULT 0,
    profit NUMERIC DEFAULT 0,
    days INTEGER DEFAULT 0,
    selected_services JSONB DEFAULT '[]'::jsonb,
    scheduled_reminders JSONB DEFAULT '[]'::jsonb,
    assigned_staff_id TEXT DEFAULT '',
    organization_id TEXT DEFAULT 'default',
    is_deleted BOOLEAN DEFAULT false,
    is_discontinued BOOLEAN DEFAULT false,
    created_by TEXT DEFAULT '',
    updated_by TEXT DEFAULT '',
    deleted_by TEXT,
    deleted_at TIMESTAMPTZ,
    discontinued_by TEXT,
    discontinued_at TIMESTAMPTZ,
    reactivated_by TEXT,
    reactivated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_patients_mr_number ON public.patients(mr_number);
CREATE INDEX IF NOT EXISTS idx_patients_assigned_staff ON public.patients(assigned_staff_id);
CREATE INDEX IF NOT EXISTS idx_patients_created_by ON public.patients(created_by);
CREATE INDEX IF NOT EXISTS idx_patients_is_deleted ON public.patients(is_deleted);
CREATE INDEX IF NOT EXISTS idx_patients_created_at ON public.patients(created_at DESC);

-- ============================================================================
-- 4. INVOICES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.invoices (
    id TEXT PRIMARY KEY,
    invoice_number TEXT NOT NULL,
    patient_id TEXT,
    subtotal NUMERIC DEFAULT 0,
    discount NUMERIC DEFAULT 0,
    grand_total NUMERIC DEFAULT 0,
    days INTEGER DEFAULT 0,
    from_date TIMESTAMPTZ,
    to_date TIMESTAMPTZ,
    items JSONB DEFAULT '[]'::jsonb,
    payment_status TEXT DEFAULT 'Unpaid' CHECK (payment_status IN ('Paid', 'Unpaid', 'Partial', 'Pending')),
    staff_id TEXT DEFAULT '',
    created_by TEXT DEFAULT '',
    created_by_name TEXT DEFAULT '',
    created_by_role TEXT DEFAULT 'staff',
    organization_id TEXT DEFAULT 'default',
    is_deleted BOOLEAN DEFAULT false,
    is_discontinued BOOLEAN DEFAULT false,
    deleted_by TEXT,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_invoices_number ON public.invoices(invoice_number);
CREATE INDEX IF NOT EXISTS idx_invoices_patient_id ON public.invoices(patient_id);
CREATE INDEX IF NOT EXISTS idx_invoices_staff_id ON public.invoices(staff_id);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON public.invoices(payment_status);
CREATE INDEX IF NOT EXISTS idx_invoices_is_deleted ON public.invoices(is_deleted);
CREATE INDEX IF NOT EXISTS idx_invoices_created_at ON public.invoices(created_at DESC);

-- ============================================================================
-- 5. ACTIVITIES (AUDIT TRAIL) TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT DEFAULT '',
    user_name TEXT DEFAULT '',
    role TEXT DEFAULT '',
    action TEXT NOT NULL,
    entity_type TEXT DEFAULT '',
    entity_id TEXT DEFAULT '',
    description TEXT NOT NULL,
    organization_id TEXT DEFAULT 'default',
    timestamp TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_activities_timestamp ON public.activities(timestamp DESC);

-- ============================================================================
-- 6. SCHEDULED NOTIFICATIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.scheduled_notifications (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    scheduled_time TIMESTAMPTZ NOT NULL,
    patient_id TEXT DEFAULT '',
    is_sent BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================================
-- 7. SYSTEM METRICS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.system_metrics (
    organization_id TEXT PRIMARY KEY,
    total_patients INTEGER DEFAULT 0,
    total_invoices INTEGER DEFAULT 0,
    total_revenue NUMERIC DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================================
-- 8. HELPER RPC FUNCTIONS (ZERO CLOUD FUNCTIONS REQUIRED!)
-- ============================================================================

-- Function: Resolve username to email for login
CREATE OR REPLACE FUNCTION public.resolve_username_to_email(p_username TEXT)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT email FROM public.users
    WHERE UPPER(username) = UPPER(TRIM(p_username))
    LIMIT 1;
$$;

-- Function: Helper to check if caller is an admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role = 'admin' AND status = 'active'
  );
$$;

-- Function: Create Staff User without logging out Admin
CREATE OR REPLACE FUNCTION public.create_staff_user(
    p_email TEXT,
    p_password TEXT,
    p_username TEXT,
    p_name TEXT,
    p_role TEXT DEFAULT 'staff',
    p_phone TEXT DEFAULT '',
    p_organization_id TEXT DEFAULT 'default'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_user_id UUID;
    encrypted_pw TEXT;
    clean_username TEXT;
    clean_email TEXT;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() AND role = 'admin' AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'Permission denied: Only active Admins can create staff accounts.';
    END IF;

    clean_username := UPPER(TRIM(p_username));
    clean_email := LOWER(TRIM(p_email));

    IF EXISTS (
        SELECT 1 FROM public.users
        WHERE UPPER(username) = clean_username AND is_deleted = false
    ) THEN
        RAISE EXCEPTION 'Username "%" already exists.', clean_username;
    END IF;

    DELETE FROM auth.identities WHERE identity_data->>'email' = clean_email;
    DELETE FROM public.users WHERE UPPER(username) = clean_username;
    DELETE FROM auth.users WHERE LOWER(email) = clean_email;

    new_user_id := gen_random_uuid();
    encrypted_pw := crypt(p_password, gen_salt('bf'));

    -- A. Insert into auth.users directly with ALL required non-null string columns
    INSERT INTO auth.users (
        id,
        instance_id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        confirmation_token,
        recovery_token,
        email_change_token_new,
        email_change_token_current,
        email_change,
        phone,
        phone_change,
        phone_change_token
    ) VALUES (
        new_user_id,
        '00000000-0000-0000-0000-000000000000',
        'authenticated',
        'authenticated',
        clean_email,
        encrypted_pw,
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('name', p_name, 'username', clean_username, 'role', p_role),
        now(),
        now(),
        '',
        '',
        '',
        '',
        '',
        COALESCE(p_phone, ''),
        '',
        ''
    );

    -- B. Insert into auth.identities
    INSERT INTO auth.identities (
        id,
        user_id,
        provider_id,
        identity_data,
        provider,
        last_sign_in_at,
        created_at,
        updated_at
    ) VALUES (
        gen_random_uuid(),
        new_user_id,
        new_user_id::text,
        format('{"sub": "%s", "email": "%s"}', new_user_id::text, clean_email)::jsonb,
        'email',
        now(),
        now(),
        now()
    );

    -- C. Insert into public.users profile
    INSERT INTO public.users (
        id,
        username,
        name,
        email,
        phone,
        role,
        status,
        organization_id,
        created_by,
        created_at,
        updated_at
    ) VALUES (
        new_user_id,
        clean_username,
        p_name,
        clean_email,
        COALESCE(p_phone, ''),
        p_role,
        'active',
        p_organization_id,
        auth.uid()::text,
        now(),
        now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'uid', new_user_id,
        'username', clean_username,
        'email', clean_email
    );
END;
$$;

-- Function: Toggle User Status (Deactivate / Reactivate with 100% sync!)
CREATE OR REPLACE FUNCTION public.toggle_user_status(
    p_target_uid UUID,
    p_status TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() AND role = 'admin' AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'Permission denied: Only active Admins can manage user status.';
    END IF;

    UPDATE public.users
    SET
        status = p_status,
        deactivated_at = CASE WHEN p_status = 'deactivated' THEN now() ELSE NULL END,
        reactivated_at = CASE WHEN p_status = 'active' THEN now() ELSE reactivated_at END,
        updated_at = now()
    WHERE id = p_target_uid;

    IF p_status = 'deactivated' THEN
        UPDATE auth.users
        SET banned_until = '2099-01-01 00:00:00+00'
        WHERE id = p_target_uid;
    ELSE
        UPDATE auth.users
        SET banned_until = NULL
        WHERE id = p_target_uid;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'uid', p_target_uid,
        'status', p_status
    );
END;
$$;

-- Function: Delete User Account (Purges from public.users, auth.identities, auth.users)
CREATE OR REPLACE FUNCTION public.delete_user_account(p_target_uid UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() AND role = 'admin' AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'Permission denied: Only active Admins can delete user accounts.';
    END IF;

    DELETE FROM auth.identities WHERE user_id = p_target_uid;
    DELETE FROM public.users WHERE id = p_target_uid;
    DELETE FROM auth.users WHERE id = p_target_uid;

    RETURN jsonb_build_object(
        'success', true,
        'uid', p_target_uid
    );
END;
$$;

-- Function: Compute live system metrics
CREATE OR REPLACE FUNCTION public.get_financial_metrics(p_org_id TEXT DEFAULT 'default')
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT jsonb_build_object(
        'totalPatients', (SELECT COUNT(*) FROM public.patients WHERE is_deleted = false AND organization_id = p_org_id),
        'totalInvoices', (SELECT COUNT(*) FROM public.invoices WHERE is_deleted = false AND organization_id = p_org_id),
        'totalRevenue', COALESCE((SELECT SUM(grand_total) FROM public.invoices WHERE is_deleted = false AND payment_status = 'Paid' AND organization_id = p_org_id), 0),
        'pendingRevenue', COALESCE((SELECT SUM(grand_total) FROM public.invoices WHERE is_deleted = false AND payment_status != 'Paid' AND organization_id = p_org_id), 0)
    );
$$;

-- ============================================================================
-- 9. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scheduled_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_metrics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow read profiles" ON public.users
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow admin manage profiles" ON public.users
    FOR ALL TO authenticated
    USING (public.is_admin());

CREATE POLICY "Allow read patients" ON public.patients
    FOR SELECT TO authenticated
    USING (is_deleted = false OR public.is_admin());

CREATE POLICY "Allow insert patients" ON public.patients
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow update patients" ON public.patients
    FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Allow delete patients" ON public.patients
    FOR DELETE TO authenticated
    USING (public.is_admin());

CREATE POLICY "Allow read invoices" ON public.invoices
    FOR SELECT TO authenticated
    USING (is_deleted = false OR public.is_admin());

CREATE POLICY "Allow insert invoices" ON public.invoices
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow update invoices" ON public.invoices
    FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Allow delete invoices" ON public.invoices
    FOR DELETE TO authenticated
    USING (public.is_admin());

CREATE POLICY "Allow read activities" ON public.activities
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow insert activities" ON public.activities
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow notifications" ON public.scheduled_notifications
    FOR ALL TO authenticated USING (true);

CREATE POLICY "Allow metrics" ON public.system_metrics
    FOR ALL TO authenticated USING (true);

-- ============================================================================
-- 10. REALTIME PUBLICATION
-- ============================================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.patients;
ALTER PUBLICATION supabase_realtime ADD TABLE public.invoices;
ALTER PUBLICATION supabase_realtime ADD TABLE public.activities;
ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
