
export default function AppLayout({
    children,
}: Readonly<{
    children: React.ReactNode;
}>) {
    return (
        <section className="w-full">
            {/* NavBar  */}
            <main className="w-full">
                {children}
            </main>
            {/* Footer */}
        </section>
    );
}