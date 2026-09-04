using UnityEngine;

[RequireComponent(typeof(Rigidbody))]
public class TopDownRigidbodyMovement : MonoBehaviour
{
    public float moveSpeed = 6f;
    public float acceleration = 20f;

    private Rigidbody rb;
    private Vector3 movement;


    void Awake()
    {
        rb = GetComponent<Rigidbody>();
    }


    void Update()
    {
        float x = Input.GetAxisRaw("Horizontal");
        float z = Input.GetAxisRaw("Vertical");

        movement = new Vector3(x, 0, z).normalized;
    }


    void FixedUpdate()
    {
        Vector3 targetVelocity = movement * moveSpeed;

        Vector3 velocity = rb.linearVelocity;

        Vector3 newVelocity = Vector3.MoveTowards(
            new Vector3(velocity.x, 0, velocity.z),
            targetVelocity,
            acceleration * Time.fixedDeltaTime
        );

        rb.linearVelocity = new Vector3(
            newVelocity.x,
            velocity.y,
            newVelocity.z
        );
    }
}