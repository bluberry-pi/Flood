using UnityEngine;

public class BoatWake : MonoBehaviour
{
    public ParticleSystem[] wakes;

    public float minBoatSpeed = 0.05f;
    public float emissionDistance = 0.15f;

    private Vector3 previousPosition;
    private float distanceSinceEmission;

    void Start()
    {
        previousPosition = transform.position;
    }

    void Update()
    {
        Vector3 movement = transform.position - previousPosition;

        // Ignore vertical movement
        movement.y = 0f;

        float distance = movement.magnitude;

        // Only create foam when the boat is moving
        if (distance > minBoatSpeed * Time.deltaTime)
        {
            Vector3 movementDirection = movement.normalized;

            distanceSinceEmission += distance;

            if (emissionDistance > 0.01f)
            {
                while (distanceSinceEmission >= emissionDistance)
                {
                    SpawnWake(movementDirection);
                    distanceSinceEmission -= emissionDistance;
                }
            }
        }

        previousPosition = transform.position;
    }

    void SpawnWake(Vector3 movementDirection)
    {
        Vector3 backward = -movementDirection;
        Vector3 sideways = Vector3.Cross(Vector3.up, movementDirection);

        ParticleSystem.EmitParams emitParams = new ParticleSystem.EmitParams();

        emitParams.velocity =
            backward * Random.Range(0.4f, 0.8f) +
            sideways * Random.Range(-0.3f, 0.3f);

        // Emit from every particle system in the array
        foreach (ParticleSystem wake in wakes)
        {
            if (wake != null)
            {
                wake.Emit(emitParams, 1);
            }
        }
    }
}