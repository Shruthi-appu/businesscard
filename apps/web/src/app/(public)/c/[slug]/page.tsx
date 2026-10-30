export default async function PublicCardPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  return (
    <section className="panel">
      <h1>Public card</h1>
      <p>Public cards are not part of this phase. Nothing is loaded for this link.</p>
      <p>Reference: {slug}</p>
    </section>
  );
}
