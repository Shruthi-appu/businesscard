export default async function SharePage({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  const prefix = token.slice(0, 4);
  return (
    <section className="panel">
      <h1>Shared card</h1>
      <p>Share links are not part of this phase. This page does not reveal a contact.</p>
      <p>Token prefix: {prefix}</p>
    </section>
  );
}
